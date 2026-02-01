import SwiftUI

struct MainView: View {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var screenCapture = ScreenCaptureService()
    @StateObject private var inputControl = InputControlService()
    // ActionExecutor is initialized in .onAppear to share the same inputControl instance
    @State private var actionExecutor: ActionExecutor?

    @State private var inputText = ""
    @State private var processingSessionIDs: Set<UUID> = []
    @State private var showSettings = false
    @State private var showNewSession = false
    @State private var showOverlay = false
    @State private var hidePreview = false
    @State private var overlayAnnotations: [CanvasAnnotation] = []
    @State private var streamingContent: String = ""
    @State private var isStreaming = false
    @State private var autoExecuteActions = true

    // Current provider settings
    @AppStorage("selectedProvider") private var selectedProviderRaw = LLMProviderType.grok.rawValue
    @AppStorage("selectedModel") private var selectedModel = "grok-4-1-fast"
    @AppStorage("systemPrompt") private var systemPrompt = ActionSystemPrompt.defaultPrompt
    @AppStorage("maxTokens") private var maxTokens = 4096
    @AppStorage("temperature") private var temperature = 0.7

    @AppStorage("apiKey_openai") private var openaiKey = ""
    @AppStorage("apiKey_anthropic") private var anthropicKey = ""
    @AppStorage("apiKey_gemini") private var geminiKey = ""
    @AppStorage("apiKey_grok") private var grokKey = ""

    private var selectedProvider: LLMProviderType {
        LLMProviderType(rawValue: selectedProviderRaw) ?? .grok
    }

    private var currentAPIKey: String {
        switch selectedProvider {
        case .openai: return openaiKey
        case .anthropic: return anthropicKey
        case .gemini: return geminiKey
        case .grok: return grokKey
        }
    }

    private var isProcessing: Bool {
        guard let id = sessionManager.activeSessionID else { return false }
        return processingSessionIDs.contains(id)
    }

    var body: some View {
        HSplitView {
            // Left sidebar: Sessions
            SessionSidebar(sessionManager: sessionManager) {
                showNewSession = true
            }
            .frame(minWidth: 200, maxWidth: 260)

            // Center: Canvas
            VStack(spacing: 0) {
                // Toolbar
                CanvasToolbar(
                    isCapturing: screenCapture.isCapturing,
                    showOverlay: $showOverlay,
                    hidePreview: $hidePreview,
                    onToggleCapture: toggleCapture,
                    onSettings: { showSettings = true },
                    onExportScreenshot: exportScreenshot,
                    provider: selectedProvider,
                    model: selectedModel
                )

                // Canvas
                CanvasView(
                    frame: screenCapture.currentFrame,
                    fps: screenCapture.fps,
                    latencyMs: screenCapture.latencyMs,
                    showOverlay: $showOverlay,
                    overlayAnnotations: $overlayAnnotations,
                    hidePreview: $hidePreview
                )
                .frame(minWidth: 400, minHeight: 300)
            }

            // Right: Chat
            VStack(spacing: 0) {
                if sessionManager.activeSession != nil {
                    ChatView(
                        messages: bindingForMessages(),
                        inputText: $inputText,
                        isProcessing: isProcessing,
                        onSend: { text in sendMessage(text, withScreenshot: false) },
                        onSendWithScreenshot: { text in sendMessage(text, withScreenshot: true) }
                    )
                } else {
                    NoSessionView(onNewSession: { showNewSession = true })
                }
            }
            .frame(minWidth: 300, maxWidth: 500)
        }
        .frame(minWidth: 1000, minHeight: 600)
        .sheet(isPresented: $showSettings) {
            SettingsView(
                isPresented: $showSettings,
                selectedProvider: Binding(
                    get: { selectedProvider },
                    set: { selectedProviderRaw = $0.rawValue }
                ),
                apiKey: bindingForCurrentKey(),
                selectedModel: $selectedModel,
                systemPrompt: $systemPrompt,
                maxTokens: $maxTokens,
                temperature: $temperature
            )
        }
        .sheet(isPresented: $showNewSession) {
            NewSessionSheet(
                isPresented: $showNewSession,
                sessionManager: sessionManager,
                defaultProvider: selectedProvider,
                defaultModel: selectedModel,
                defaultAPIKey: currentAPIKey
            )
        }
        .onAppear {
            _ = inputControl.checkPermissions()
            if actionExecutor == nil {
                actionExecutor = ActionExecutor(inputControl: inputControl)
                Log.info("ActionExecutor initialized with shared InputControlService")
            }
            Log.info("App started. Accessibility: \(inputControl.hasAccessibilityPermission)")
        }
        .alert("Screen Capture Error", isPresented: Binding(
            get: { screenCapture.error != nil },
            set: { if !$0 { screenCapture.error = nil } }
        )) {
            Button("OK") { screenCapture.error = nil }
        } message: {
            Text(screenCapture.error ?? "")
        }
    }

    // MARK: - Actions

    private func toggleCapture() {
        Task {
            if screenCapture.isCapturing {
                await screenCapture.stopCapture()
            } else {
                await screenCapture.startCapture()
            }
        }
    }

    private func sendMessage(_ text: String, withScreenshot: Bool) {
        guard let sessionID = sessionManager.activeSessionID else { return }

        // Auto-attach screenshot when capture is running, so the AI always has visual context
        let shouldAttachScreenshot = withScreenshot || screenCapture.isCapturing

        Log.info("User message: \"\(text.prefix(80))\" (screenshot: \(shouldAttachScreenshot)\(shouldAttachScreenshot && !withScreenshot ? " [auto]" : ""))")

        var imageData: Data?

        if shouldAttachScreenshot, let frame = screenCapture.currentFrame, let cgImage = frame.image {
            if let resized = ImageUtils.resize(cgImage, maxDimension: 1280) {
                imageData = ImageUtils.pngData(from: resized)
                Log.info("Screenshot attached: \(resized.width)x\(resized.height) (resized)")
            } else {
                imageData = ImageUtils.pngData(from: cgImage)
                Log.info("Screenshot attached: \(cgImage.width)x\(cgImage.height)")
            }
        }

        let userMessage = ChatMessage(
            role: .user,
            content: text,
            hasImage: imageData != nil,
            imageData: imageData
        )
        sessionManager.addMessage(to: sessionID, message: userMessage)

        // Add a placeholder assistant message for streaming
        let placeholderMessage = ChatMessage(role: .assistant, content: "...")
        let placeholderID = placeholderMessage.id
        sessionManager.addMessage(to: sessionID, message: placeholderMessage)

        processingSessionIDs.insert(sessionID)
        streamingContent = ""
        isStreaming = true

        Task {
            do {
                Log.llm("Sending to LLM...")
                let response = try await callLLM(sessionID: sessionID, placeholderID: placeholderID)
                Log.llm("LLM response received (\(response.content.count) chars, tokens: \(response.tokensUsed ?? 0))")

                await MainActor.run {
                    // Replace placeholder with final response
                    updatePlaceholder(sessionID: sessionID, placeholderID: placeholderID, content: response.content)
                }

                // Parse and execute actions from the response
                if autoExecuteActions {
                    await handleActionsFromResponse(response.content, sessionID: sessionID)
                }

                await MainActor.run {
                    processingSessionIDs.remove(sessionID)
                    isStreaming = false
                }
            } catch {
                Log.error("LLM call failed: \(error.localizedDescription)")
                await MainActor.run {
                    // Replace placeholder with error
                    removePlaceholder(sessionID: sessionID, placeholderID: placeholderID)
                    let errorMessage = ChatMessage(role: .error, content: "Error: \(error.localizedDescription)")
                    sessionManager.addMessage(to: sessionID, message: errorMessage)
                    processingSessionIDs.remove(sessionID)
                    isStreaming = false
                }
            }
        }
    }

    private static let maxFollowUpRounds = 5

    /// Parse actions from LLM response, execute them, and optionally take a follow-up screenshot
    private func handleActionsFromResponse(_ responseContent: String, sessionID: UUID, depth: Int = 0) async {
        let parsed = ActionParser.parse(responseContent)

        if !parsed.explanation.isEmpty {
            Log.llm("AI explanation: \(parsed.explanation.prefix(120))")
        }

        guard !parsed.actions.isEmpty else {
            Log.info("No executable actions found in response (conversational reply)")
            return
        }

        Log.action("Parsed \(parsed.actions.count) action(s) from response (depth: \(depth)/\(Self.maxFollowUpRounds)):")
        for (i, action) in parsed.actions.enumerated() {
            Log.action("  [\(i + 1)] \(action.description)")
        }

        // Check if any action is a screenshot request
        let hasScreenshotRequest = parsed.actions.contains { if case .screenshot = $0 { return true } else { return false } }

        // Execute the actions
        guard let executor = actionExecutor else {
            Log.error("ActionExecutor not initialized - cannot execute actions")
            return
        }
        await executor.execute(actions: parsed.actions)

        Log.action("All actions executed. History: \(executor.actionHistory.count) entries")

        // If the AI requested a screenshot, take one and send it back automatically
        if hasScreenshotRequest {
            guard depth < Self.maxFollowUpRounds else {
                Log.info("Max follow-up depth reached (\(Self.maxFollowUpRounds)). Stopping auto-loop.")
                await MainActor.run {
                    let msg = ChatMessage(role: .system, content: "[System: Max follow-up rounds reached. Send another message to continue.]")
                    sessionManager.addMessage(to: sessionID, message: msg)
                }
                return
            }

            Log.info("AI requested a screenshot - capturing and sending back... (round \(depth + 1)/\(Self.maxFollowUpRounds))")
            // Brief delay to let UI settle after actions
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            await sendFollowUpScreenshot(sessionID: sessionID, depth: depth + 1)
        }
    }

    /// Automatically capture and send a screenshot back to the AI after action execution
    private func sendFollowUpScreenshot(sessionID: UUID, depth: Int) async {
        guard let frame = await MainActor.run(body: { screenCapture.currentFrame }),
              let cgImage = frame.image else {
            Log.error("Cannot take follow-up screenshot - no frame available")
            return
        }

        var imageData: Data?
        if let resized = ImageUtils.resize(cgImage, maxDimension: 1280) {
            imageData = ImageUtils.pngData(from: resized)
        } else {
            imageData = ImageUtils.pngData(from: cgImage)
        }

        await MainActor.run {
            let followUp = ChatMessage(
                role: .user,
                content: "[Auto-screenshot after action execution] Describe what you see now. If you need to continue with more actions, output them as JSON. If the task appears complete, say so.",
                hasImage: imageData != nil,
                imageData: imageData
            )
            sessionManager.addMessage(to: sessionID, message: followUp)
        }
        Log.info("Follow-up screenshot sent to LLM")

        let placeholder = ChatMessage(role: .assistant, content: "...")
        let placeholderID = placeholder.id
        await MainActor.run {
            sessionManager.addMessage(to: sessionID, message: placeholder)
            streamingContent = ""
        }

        do {
            let response = try await callLLM(sessionID: sessionID, placeholderID: placeholderID)
            Log.llm("Follow-up response received (\(response.content.count) chars)")

            await MainActor.run {
                updatePlaceholder(sessionID: sessionID, placeholderID: placeholderID, content: response.content)
            }

            // Recursively handle actions from follow-up with incremented depth
            await handleActionsFromResponse(response.content, sessionID: sessionID, depth: depth)

            await MainActor.run {
                processingSessionIDs.remove(sessionID)
                isStreaming = false
            }
        } catch {
            Log.error("Follow-up LLM call failed: \(error.localizedDescription)")
            await MainActor.run {
                removePlaceholder(sessionID: sessionID, placeholderID: placeholderID)
                let errorMessage = ChatMessage(role: .error, content: "Follow-up error: \(error.localizedDescription)")
                sessionManager.addMessage(to: sessionID, message: errorMessage)
                processingSessionIDs.remove(sessionID)
                isStreaming = false
            }
        }
    }

    private func updatePlaceholder(sessionID: UUID, placeholderID: UUID, content: String) {
        guard let sessionIdx = sessionManager.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        if let msgIdx = sessionManager.sessions[sessionIdx].messages.firstIndex(where: { $0.id == placeholderID }) {
            let updated = ChatMessage(role: .assistant, content: content)
            sessionManager.sessions[sessionIdx].messages[msgIdx] = updated
        }
    }

    private func removePlaceholder(sessionID: UUID, placeholderID: UUID) {
        guard let sessionIdx = sessionManager.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessionManager.sessions[sessionIdx].messages.removeAll { $0.id == placeholderID }
    }

    private func callLLM(sessionID: UUID, placeholderID: UUID) async throws -> LLMResponse {
        guard let session = await MainActor.run(body: { sessionManager.sessions.first(where: { $0.id == sessionID }) }) else {
            throw LLMError.invalidResponse("No active session")
        }

        let config = LLMProviderConfig(
            providerType: session.providerType,
            apiKey: session.apiKey,
            model: session.model,
            systemPrompt: session.systemPrompt,
            maxTokens: maxTokens,
            temperature: temperature
        )

        Log.llm("Provider: \(config.providerType.rawValue), Model: \(config.model)")

        let provider = LLMProviderFactory.create(config: config)

        // Filter out error messages and build LLM message list
        let llmMessages = session.messages
            .filter { $0.role != .error && $0.id != placeholderID }
            .suffix(20)
            .map { msg -> LLMMessage in
                let role: LLMMessage.Role
                switch msg.role {
                case .user: role = .user
                case .assistant: role = .assistant
                case .system: role = .system
                case .error: role = .user // unreachable due to filter
                }

                var imgData: Data?
                if let base64 = msg.imageDataBase64 {
                    imgData = Data(base64Encoded: base64)
                }

                return LLMMessage(role: role, content: msg.content, imageData: imgData)
            }

        let imageCount = llmMessages.filter { $0.imageData != nil }.count
        Log.llm("Sending \(llmMessages.count) messages (\(imageCount) with images)")

        var tokenCount = 0
        let response = try await provider.sendMessageStreaming(llmMessages) { token in
            tokenCount += 1
            // Log first few tokens for debugging
            if tokenCount <= 3 {
                Log.stream("Token \(tokenCount): \"\(token.prefix(40))\"")
            }
            // Update the placeholder message with streaming content
            Task { @MainActor in
                streamingContent += token
                updatePlaceholder(sessionID: sessionID, placeholderID: placeholderID, content: streamingContent)
            }
        }

        Log.stream("Streaming complete: \(tokenCount) token chunks received")
        return response
    }

    private func exportScreenshot() {
        guard let frame = screenCapture.currentFrame,
              let cgImage = frame.image,
              let data = ImageUtils.pngData(from: cgImage) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { result in
                if result == .OK, let url = panel.url {
                    try? data.write(to: url)
                }
            }
        }
    }

    private func bindingForMessages() -> Binding<[ChatMessage]> {
        Binding(
            get: {
                sessionManager.activeSession?.messages ?? []
            },
            set: { newMessages in
                if let idx = sessionManager.sessions.firstIndex(where: { $0.id == sessionManager.activeSessionID }) {
                    sessionManager.sessions[idx].messages = newMessages
                }
            }
        )
    }

    private func bindingForCurrentKey() -> Binding<String> {
        Binding(
            get: { currentAPIKey },
            set: { newKey in
                switch selectedProvider {
                case .openai: openaiKey = newKey
                case .anthropic: anthropicKey = newKey
                case .gemini: geminiKey = newKey
                case .grok: grokKey = newKey
                }
            }
        )
    }
}

// MARK: - Supporting Views

struct CanvasToolbar: View {
    let isCapturing: Bool
    @Binding var showOverlay: Bool
    @Binding var hidePreview: Bool
    let onToggleCapture: () -> Void
    let onSettings: () -> Void
    let onExportScreenshot: () -> Void
    let provider: LLMProviderType
    let model: String

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleCapture) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isCapturing ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    Text(isCapturing ? "Stop Capture" : "Start Capture")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Toggle("Overlay", isOn: $showOverlay)
                .toggleStyle(.switch)
                .controlSize(.mini)

            Toggle("Hide Preview", isOn: $hidePreview)
                .toggleStyle(.switch)
                .controlSize(.mini)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: providerIcon)
                    .font(.caption2)
                Text("\(provider.rawValue): \(model)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Button(action: onExportScreenshot) {
                Image(systemName: "camera.on.rectangle")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Export screenshot")
            .disabled(!isCapturing)

            Button(action: onSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var providerIcon: String {
        switch provider {
        case .openai: return "brain"
        case .anthropic: return "a.circle"
        case .gemini: return "sparkles"
        case .grok: return "bolt"
        }
    }
}

struct NoSessionView: View {
    let onNewSession: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.badge.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Active Session")
                .font(.title3)
                .foregroundColor(.gray)
            Text("Create a session to start chatting with an AI")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("New Session", action: onNewSession)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NewSessionSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var sessionManager: SessionManager
    let defaultProvider: LLMProviderType
    let defaultModel: String
    let defaultAPIKey: String

    @State private var name = ""
    @State private var provider: LLMProviderType = .grok
    @State private var model = ""
    @State private var apiKey = ""
    @State private var systemPrompt = ActionSystemPrompt.defaultPrompt

    @AppStorage("apiKey_openai") private var openaiKey = ""
    @AppStorage("apiKey_anthropic") private var anthropicKey = ""
    @AppStorage("apiKey_gemini") private var geminiKey = ""
    @AppStorage("apiKey_grok") private var grokKey = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("New Session")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                StyledAppKitTextField(placeholder: "Session Name", text: $name)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Picker("Provider", selection: $provider) {
                    ForEach(LLMProviderType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .onChange(of: provider) { _, newValue in
                    model = newValue.defaultModels.first ?? ""
                    loadKey(for: newValue)
                }

                Picker("Model", selection: $model) {
                    ForEach(provider.defaultModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }

                StyledAppKitSecureField(placeholder: "API Key", text: $apiKey)

                TextEditor(text: $systemPrompt)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 60)
                    .border(Color.gray.opacity(0.3))
            }

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Create") {
                    let sessionName = name.isEmpty ? "\(provider.displayName) Session" : name
                    _ = sessionManager.createSession(
                        name: sessionName,
                        providerType: provider,
                        model: model,
                        apiKey: apiKey,
                        systemPrompt: systemPrompt
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            provider = defaultProvider
            model = defaultModel
            apiKey = defaultAPIKey
            if apiKey.isEmpty {
                loadKey(for: provider)
            }
        }
    }

    private func loadKey(for p: LLMProviderType) {
        switch p {
        case .openai: apiKey = openaiKey
        case .anthropic: apiKey = anthropicKey
        case .gemini: apiKey = geminiKey
        case .grok: apiKey = grokKey
        }
    }
}

import SwiftUI

enum ResizeMode: String, CaseIterable {
    case fit1280 = "1280px"
    case tileAligned = "Tile 1344"
    case fullRes = "Full Res"
}

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
    @AppStorage("resizeMode") private var resizeMode = ResizeMode.fit1280
    @AppStorage("useSmartClick") private var useSmartClick = true
    @AppStorage("useRefineClicks") private var useRefineClicks = false
    @AppStorage("useGridOverlay") private var useGridOverlay = false
    @AppStorage("excludeOwnWindows") private var excludeOwnWindows = true
    @AppStorage("excludeTerminalWindows") private var excludeTerminalWindows = true

    @State private var calibrationResult: CalibrationResult?
    @State private var isCalibrating = false
    @State private var aiCalibrationResult: [(landmark: CalibrationLandmark, aiPoint: CGPoint, error: Double)] = []

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
                    resizeMode: $resizeMode,
                    useSmartClick: $useSmartClick,
                    useRefineClicks: $useRefineClicks,
                    useGridOverlay: $useGridOverlay,
                    excludeOwnWindows: $excludeOwnWindows,
                    excludeTerminalWindows: $excludeTerminalWindows,
                    isCalibrating: isCalibrating,
                    onToggleCapture: toggleCapture,
                    onSettings: { showSettings = true },
                    onExportScreenshot: exportScreenshot,
                    onCalibrate: runCalibration,
                    onAICalibrate: runAICalibration,
                    onReverseCal: runReverseCalibration,
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
            // Sync exclusion settings to capture service
            screenCapture.excludeOwnWindows = excludeOwnWindows
            screenCapture.excludeTerminalWindows = excludeTerminalWindows
            Log.info("App started. Accessibility: \(inputControl.hasAccessibilityPermission)")
        }
        .onChange(of: excludeOwnWindows) { _, newValue in
            screenCapture.excludeOwnWindows = newValue
            restartCaptureIfNeeded()
        }
        .onChange(of: excludeTerminalWindows) { _, newValue in
            screenCapture.excludeTerminalWindows = newValue
            restartCaptureIfNeeded()
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

    private func restartCaptureIfNeeded() {
        guard screenCapture.isCapturing else { return }
        Task {
            Log.info("Restarting capture with updated exclusion settings")
            await screenCapture.stopCapture()
            await screenCapture.startCapture()
        }
    }

    private func runCalibration() {
        guard screenCapture.displayPointWidth > 0 else {
            Log.error("Cannot calibrate - no display dimensions available. Start capture first.")
            return
        }
        isCalibrating = true
        let result = inputControl.runCalibration(
            displayWidth: screenCapture.displayPointWidth,
            displayHeight: screenCapture.displayPointHeight
        )
        calibrationResult = result

        // Show calibration results as overlay annotations
        var annotations: [CanvasAnnotation] = []
        let screenW = screenCapture.currentFrame?.width ?? screenCapture.displayPointWidth
        let screenH = screenCapture.currentFrame?.height ?? screenCapture.displayPointHeight

        for point in result.points {
            let color: Color = point.errorPixels < 2 ? .green : point.errorPixels < 5 ? .yellow : .red
            annotations.append(.fromScreenPoint(
                x: Int(point.target.x), y: Int(point.target.y),
                screenWidth: screenW, screenHeight: screenH,
                label: "\(point.label): \(String(format: "%.1f", point.errorPixels))px",
                color: color
            ))
        }
        overlayAnnotations = annotations
        showOverlay = true
        isCalibrating = false

        Log.info("Calibration: avg=\(String(format: "%.1f", result.averageError))px, max=\(String(format: "%.1f", result.maxError))px, passed=\(result.passed)")
    }

    private func sendMessage(_ text: String, withScreenshot: Bool) {
        guard let sessionID = sessionManager.activeSessionID else { return }

        // Auto-attach screenshot when capture is running, so the AI always has visual context
        let shouldAttachScreenshot = withScreenshot || screenCapture.isCapturing

        Log.info("User message: \"\(text.prefix(80))\" (screenshot: \(shouldAttachScreenshot)\(shouldAttachScreenshot && !withScreenshot ? " [auto]" : ""))")

        var imageData: Data?

        if shouldAttachScreenshot, let frame = screenCapture.currentFrame, let cgImage = frame.image {
            switch resizeMode {
            case .fullRes:
                imageData = ImageUtils.pngData(from: cgImage)
                Log.info("Screenshot attached: \(cgImage.width)x\(cgImage.height) (full res)")
            case .tileAligned:
                if let (canvas, info) = ImageUtils.resizeToCanvas(cgImage, targetWidth: 1344, targetHeight: 896) {
                    let finalCanvas = useGridOverlay ? (ImageUtils.drawGrid(on: canvas) ?? canvas) : canvas
                    imageData = ImageUtils.pngData(from: finalCanvas)
                    Log.info("Screenshot attached: \(info.canvasWidth)x\(info.canvasHeight) tile-aligned\(useGridOverlay ? " +grid" : "") (image \(info.imageWidth)x\(info.imageHeight) offset \(info.offsetX),\(info.offsetY))")
                } else {
                    imageData = ImageUtils.pngData(from: cgImage)
                    Log.info("Screenshot attached: \(cgImage.width)x\(cgImage.height) (tile-align failed, using raw)")
                }
            case .fit1280:
                if let resized = ImageUtils.resize(cgImage, maxDimension: 1280) {
                    imageData = ImageUtils.pngData(from: resized)
                    Log.info("Screenshot attached: \(resized.width)x\(resized.height) (resized)")
                } else {
                    imageData = ImageUtils.pngData(from: cgImage)
                    Log.info("Screenshot attached: \(cgImage.width)x\(cgImage.height)")
                }
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

    private static let maxFollowUpRounds = 100

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

        // Update overlay annotations from parsed actions so the user can see what the AI targets
        await MainActor.run {
            updateOverlayAnnotations(from: parsed.actions)
        }

        // Check if any action is a screenshot request
        let hasScreenshotRequest = parsed.actions.contains { if case .screenshot = $0 { return true } else { return false } }

        // Execute the actions
        guard let executor = actionExecutor else {
            Log.error("ActionExecutor not initialized - cannot execute actions")
            return
        }

        let coordinateContext: CoordinateContext?
        switch resizeMode {
        case .fullRes:
            coordinateContext = nil  // AI coords == display points
        case .tileAligned:
            if let frame = screenCapture.currentFrame,
               let cgImage = frame.image,
               screenCapture.displayPointWidth > 0,
               let (_, info) = ImageUtils.resizeToCanvas(cgImage, targetWidth: 1344, targetHeight: 896) {
                coordinateContext = CoordinateContext(
                    displayWidth: screenCapture.displayPointWidth,
                    displayHeight: screenCapture.displayPointHeight,
                    imageWidth: info.canvasWidth, imageHeight: info.canvasHeight,
                    letterboxOffsetX: info.offsetX, letterboxOffsetY: info.offsetY,
                    letterboxImageW: info.imageWidth, letterboxImageH: info.imageHeight
                )
            } else {
                coordinateContext = nil
            }
        case .fit1280:
            if let frame = screenCapture.currentFrame,
               screenCapture.displayPointWidth > 0 {
                let (imgW, imgH) = resizedImageDimensions(frame: frame)
                coordinateContext = CoordinateContext(
                    displayWidth: screenCapture.displayPointWidth,
                    displayHeight: screenCapture.displayPointHeight,
                    imageWidth: imgW, imageHeight: imgH
                )
            } else {
                coordinateContext = nil
            }
        }

        // Pre-map actions to screen coordinates, then optionally refine BEFORE execution
        var mappedActions = executor.mapActions(parsed.actions, coordinateContext: coordinateContext)

        if useRefineClicks {
            for i in mappedActions.indices {
                if case .click(let sx, let sy) = mappedActions[i] {
                    let (rx, ry) = await refineClickCoordinate(x: sx, y: sy, sessionID: sessionID)
                    if rx != sx || ry != sy {
                        Log.info("Pre-refine: (\(sx), \(sy)) -> (\(rx), \(ry))")
                        mappedActions[i] = .click(x: rx, y: ry)
                    }
                }
            }
        }

        // Execute already-mapped actions (no coordinateContext needed)
        await executor.execute(actions: mappedActions, coordinateContext: nil)

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
        switch resizeMode {
        case .fullRes:
            imageData = ImageUtils.pngData(from: cgImage)
        case .tileAligned:
            if let (canvas, _) = ImageUtils.resizeToCanvas(cgImage, targetWidth: 1344, targetHeight: 896) {
                let finalCanvas = useGridOverlay ? (ImageUtils.drawGrid(on: canvas) ?? canvas) : canvas
                imageData = ImageUtils.pngData(from: finalCanvas)
            } else {
                imageData = ImageUtils.pngData(from: cgImage)
            }
        case .fit1280:
            if let resized = ImageUtils.resize(cgImage, maxDimension: 1280) {
                imageData = ImageUtils.pngData(from: resized)
            } else {
                imageData = ImageUtils.pngData(from: cgImage)
            }
        }

        let recentActions: String = await MainActor.run {
            guard let executor = actionExecutor else { return "" }
            let recent = executor.actionHistory.suffix(5)
            if recent.isEmpty { return "" }
            let lines = recent.enumerated().map { (i, entry) in
                let status = entry.success ? "OK" : "FAILED"
                return "[\(i+1)] \(entry.action) — \(status): \(entry.detail)"
            }
            return "\nRecent actions:\n" + lines.joined(separator: "\n")
        }

        await MainActor.run {
            let followUp = ChatMessage(
                role: .user,
                content: "[Auto-screenshot after action execution]\(recentActions)\n\nDescribe what you see now. If any actions FAILED above, try a different approach (e.g., use coordinate click instead of click_element). If you need to continue, output JSON actions. If the task appears complete, say so.",
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

        var config = LLMProviderConfig(
            providerType: session.providerType,
            apiKey: session.apiKey,
            model: session.model,
            systemPrompt: session.systemPrompt,
            maxTokens: maxTokens,
            temperature: temperature
        )

        // Inject dynamic image dimensions so the AI knows the exact coordinate space
        let frameDimensions: (imageW: Int, imageH: Int)? = await MainActor.run {
            guard let frame = screenCapture.currentFrame,
                  screenCapture.displayPointWidth > 0 else { return nil }
            switch resizeMode {
            case .fullRes:
                return (frame.width, frame.height)
            case .tileAligned:
                return (1344, 896)  // report canvas dimensions
            case .fit1280:
                return resizedImageDimensions(frame: frame)
            }
        }
        if let dims = frameDimensions {
            config.systemPrompt += """
            \n
            ## Current Screenshot Info
            - The screenshot image is **\(dims.imageW)x\(dims.imageH) pixels**.
            - Valid coordinate ranges: x in [0, \(dims.imageW - 1)], y in [0, \(dims.imageH - 1)].
            - **NEVER output coordinates outside these ranges.** Out-of-bounds clicks will be clamped and may hit unintended targets.
            - **WARNING:** Clicking on empty desktop/wallpaper areas will hide all windows on macOS Sonoma+.
            """
        }

        // Always include coordinate system info
        config.systemPrompt += ActionSystemPrompt.coordinateSystemSection

        // Include click_region docs (always available, lightweight)
        config.systemPrompt += ActionSystemPrompt.clickRegionSection

        // Desktop interaction guidance (always include)
        config.systemPrompt += ActionSystemPrompt.desktopInteractionSection

        // Grid overlay docs (when grid is active in tile mode)
        if useGridOverlay && resizeMode == .tileAligned {
            config.systemPrompt += ActionSystemPrompt.gridOverlaySection
        }

        if useSmartClick {
            config.systemPrompt += ActionSystemPrompt.smartClickSection
        }

        Log.llm("Provider: \(config.providerType.rawValue), Model: \(config.model)")

        let provider = LLMProviderFactory.create(config: config)

        // Filter out error messages and build LLM message list
        let filtered = session.messages
            .filter { $0.role != .error && $0.id != placeholderID }

        // Always keep the first user message (original task) in context
        let firstUserMessage = filtered.first { $0.role == .user }
        let recentMessages = Array(filtered.suffix(20))
        let pinnedMessages: [ChatMessage]

        if let first = firstUserMessage, !recentMessages.contains(where: { $0.id == first.id }) {
            // Original task fell out of window — pin it at the front
            pinnedMessages = [first] + Array(filtered.suffix(19))
        } else {
            pinnedMessages = recentMessages
        }

        let llmMessages = pinnedMessages
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

    /// Convert parsed AI actions into visual overlay annotations
    private func updateOverlayAnnotations(from actions: [AIAction]) {
        let screenW: Int
        let screenH: Int
        switch resizeMode {
        case .fullRes:
            screenW = screenCapture.currentFrame?.width ?? 1920
            screenH = screenCapture.currentFrame?.height ?? 1080
        case .tileAligned:
            screenW = 1344
            screenH = 896
        case .fit1280:
            let nativeW = screenCapture.currentFrame?.width ?? 1920
            let nativeH = screenCapture.currentFrame?.height ?? 1080
            let maxDim = 1280
            let scale = min(Double(maxDim) / Double(max(nativeW, nativeH)), 1.0)
            screenW = Int(Double(nativeW) * scale)
            screenH = Int(Double(nativeH) * scale)
        }

        var annotations: [CanvasAnnotation] = []

        for (i, action) in actions.enumerated() {
            let stepLabel = actions.count > 1 ? "[\(i + 1)] " : ""
            switch action {
            case .click(let x, let y):
                annotations.append(.fromScreenPoint(x: x, y: y, screenWidth: screenW, screenHeight: screenH,
                                                     label: "\(stepLabel)Click", color: .green))
            case .rightClick(let x, let y):
                annotations.append(.fromScreenPoint(x: x, y: y, screenWidth: screenW, screenHeight: screenH,
                                                     label: "\(stepLabel)Right-Click", color: .orange))
            case .doubleClick(let x, let y):
                annotations.append(.fromScreenPoint(x: x, y: y, screenWidth: screenW, screenHeight: screenH,
                                                     label: "\(stepLabel)Dbl-Click", color: .yellow))
            case .moveMouse(let x, let y):
                annotations.append(.fromScreenPoint(x: x, y: y, screenWidth: screenW, screenHeight: screenH,
                                                     label: "\(stepLabel)Move", color: .cyan))
            case .drag(let fx, let fy, let tx, let ty):
                annotations.append(.fromScreenPoint(x: fx, y: fy, screenWidth: screenW, screenHeight: screenH,
                                                     label: "\(stepLabel)Drag Start", color: .purple))
                annotations.append(.fromScreenPoint(x: tx, y: ty, screenWidth: screenW, screenHeight: screenH,
                                                     label: "\(stepLabel)Drag End", color: .purple))
                annotations.append(.fromScreenRect(x: fx, y: fy, toX: tx, toY: ty,
                                                    screenWidth: screenW, screenHeight: screenH,
                                                    label: "", color: .purple.opacity(0.3)))
            case .clickRegion(let x1, let y1, let x2, let y2):
                annotations.append(.fromScreenRect(x: x1, y: y1, toX: x2, toY: y2,
                    screenWidth: screenW, screenHeight: screenH,
                    label: "\(stepLabel)Region", color: .mint))
                let cx = (x1 + x2) / 2, cy = (y1 + y2) / 2
                annotations.append(.fromScreenPoint(x: cx, y: cy,
                    screenWidth: screenW, screenHeight: screenH,
                    label: "\(stepLabel)Click", color: .green))
            case .clickTile(let tile, let lx, let ly):
                // Convert tile-local to global image coords for overlay
                let tileOffsets: [String: (x: Int, y: Int)] = [
                    "A1": (0, 0), "A2": (448, 0), "A3": (896, 0),
                    "B1": (0, 448), "B2": (448, 448), "B3": (896, 448),
                ]
                if let offset = tileOffsets[tile.uppercased()] {
                    let gx = offset.x + lx
                    let gy = offset.y + ly
                    annotations.append(.fromScreenPoint(x: gx, y: gy, screenWidth: screenW, screenHeight: screenH,
                                                         label: "\(stepLabel)Tile \(tile)", color: .cyan))
                }
            case .clickElement(let name):
                annotations.append(CanvasAnnotation(
                    rect: CGRect(x: 0.4, y: 0.02, width: 0.2, height: 0.04),
                    label: "\(stepLabel)Smart: \"\(name)\"",
                    color: .blue
                ))
            default:
                break
            }
        }

        overlayAnnotations = annotations

        if !annotations.isEmpty {
            showOverlay = true
            Log.info("Updated overlay: \(annotations.count) annotation(s)")
        }
    }

    /// Coarse-to-fine click refinement: crop around target, ask AI to refine coordinates
    private func refineClickCoordinate(x: Int, y: Int, sessionID: UUID) async -> (Int, Int) {
        guard let frame = screenCapture.currentFrame,
              let cgImage = frame.image else {
            Log.info("Refine: no frame available, returning original (\(x), \(y))")
            return (x, y)
        }

        let displayW = screenCapture.displayPointWidth
        let displayH = screenCapture.displayPointHeight
        guard displayW > 0, displayH > 0 else { return (x, y) }

        // Compute crop region: 300x300 display-point box centered on (x, y), clamped to screen bounds
        let cropSize = 300
        let cropX = max(0, min(x - cropSize / 2, displayW - cropSize))
        let cropY = max(0, min(y - cropSize / 2, displayH - cropSize))
        let cropW = min(cropSize, displayW - cropX)
        let cropH = min(cropSize, displayH - cropY)

        // Map display-point crop region to CGImage pixel coordinates
        let scaleX = CGFloat(cgImage.width) / CGFloat(displayW)
        let scaleY = CGFloat(cgImage.height) / CGFloat(displayH)
        let pixelRect = CGRect(
            x: CGFloat(cropX) * scaleX,
            y: CGFloat(cropY) * scaleY,
            width: CGFloat(cropW) * scaleX,
            height: CGFloat(cropH) * scaleY
        )

        guard let cropped = cgImage.cropping(to: pixelRect) else {
            Log.info("Refine: crop failed, returning original (\(x), \(y))")
            return (x, y)
        }

        // Resize crop to fit current mode dimensions
        let cropImageData: Data?
        let cropImgW: Int
        let cropImgH: Int
        switch resizeMode {
        case .fullRes:
            cropImageData = ImageUtils.pngData(from: cropped)
            cropImgW = cropped.width
            cropImgH = cropped.height
        case .tileAligned:
            if let (canvas, info) = ImageUtils.resizeToCanvas(cropped, targetWidth: 1344, targetHeight: 896) {
                cropImageData = ImageUtils.pngData(from: canvas)
                cropImgW = info.canvasWidth
                cropImgH = info.canvasHeight
            } else {
                cropImageData = ImageUtils.pngData(from: cropped)
                cropImgW = cropped.width
                cropImgH = cropped.height
            }
        case .fit1280:
            if let resized = ImageUtils.resize(cropped, maxDimension: 1280) {
                cropImageData = ImageUtils.pngData(from: resized)
                cropImgW = resized.width
                cropImgH = resized.height
            } else {
                cropImageData = ImageUtils.pngData(from: cropped)
                cropImgW = cropped.width
                cropImgH = cropped.height
            }
        }

        guard let imgData = cropImageData else { return (x, y) }

        Log.info("Refine: sending \(cropImgW)x\(cropImgH) crop around (\(x), \(y)) to LLM")

        // Build a one-shot LLM call with the crop
        let prompt = "This is a zoomed-in view of the area around (\(x), \(y)). Click the exact element that should be clicked. Your coordinates are relative to this crop. Image is \(cropImgW)x\(cropImgH) pixels. Output a single click action as JSON."

        let session = await MainActor.run { sessionManager.sessions.first(where: { $0.id == sessionID }) }
        guard let session = session else { return (x, y) }

        let config = LLMProviderConfig(
            providerType: session.providerType,
            apiKey: session.apiKey,
            model: session.model,
            systemPrompt: ActionSystemPrompt.defaultPrompt + ActionSystemPrompt.coordinateSystemSection,
            maxTokens: 256,
            temperature: 0.3
        )

        let provider = LLMProviderFactory.create(config: config)
        let messages = [LLMMessage(role: .user, content: prompt, imageData: imgData)]

        do {
            let response = try await provider.sendMessage(messages)
            let parsed = ActionParser.parse(response.content)
            if let firstClick = parsed.actions.first,
               case .click(let aiX, let aiY) = firstClick {
                // Map crop-relative coords back to full-screen display points
                let finalX = cropX + (aiX * cropW / cropImgW)
                let finalY = cropY + (aiY * cropH / cropImgH)
                Log.info("Refine: (\(x), \(y)) -> (\(finalX), \(finalY)) via crop-relative (\(aiX), \(aiY))")
                return (finalX, finalY)
            }
        } catch {
            Log.error("Refine LLM call failed: \(error.localizedDescription)")
        }

        return (x, y)
    }

    /// AI Calibration (Tier 2): ask AI to click known landmarks and measure error
    private func runAICalibration() {
        guard screenCapture.isCapturing, screenCapture.displayPointWidth > 0 else {
            Log.error("Cannot run AI calibration - capture not running")
            return
        }
        isCalibrating = true

        Task {
            let landmarks = inputControl.getCalibrationLandmarks(
                displayWidth: screenCapture.displayPointWidth,
                displayHeight: screenCapture.displayPointHeight
            )

            guard let frame = screenCapture.currentFrame,
                  let cgImage = frame.image,
                  let sessionID = sessionManager.activeSessionID,
                  let session = sessionManager.sessions.first(where: { $0.id == sessionID }) else {
                Log.error("AI Calibration: no frame or session available")
                await MainActor.run { isCalibrating = false }
                return
            }

            // Prepare screenshot image data in current resize mode
            let imageData: Data?
            let imgW: Int
            let imgH: Int
            switch resizeMode {
            case .fullRes:
                imageData = ImageUtils.pngData(from: cgImage)
                imgW = cgImage.width
                imgH = cgImage.height
            case .tileAligned:
                if let (canvas, info) = ImageUtils.resizeToCanvas(cgImage, targetWidth: 1344, targetHeight: 896) {
                    imageData = ImageUtils.pngData(from: canvas)
                    imgW = info.canvasWidth
                    imgH = info.canvasHeight
                } else {
                    imageData = ImageUtils.pngData(from: cgImage)
                    imgW = cgImage.width
                    imgH = cgImage.height
                }
            case .fit1280:
                if let resized = ImageUtils.resize(cgImage, maxDimension: 1280) {
                    imageData = ImageUtils.pngData(from: resized)
                    imgW = resized.width
                    imgH = resized.height
                } else {
                    imageData = ImageUtils.pngData(from: cgImage)
                    imgW = cgImage.width
                    imgH = cgImage.height
                }
            }

            guard let imgData = imageData else {
                await MainActor.run { isCalibrating = false }
                return
            }

            let config = LLMProviderConfig(
                providerType: session.providerType,
                apiKey: session.apiKey,
                model: session.model,
                systemPrompt: ActionSystemPrompt.defaultPrompt + ActionSystemPrompt.coordinateSystemSection,
                maxTokens: 256,
                temperature: 0.3
            )
            let provider = LLMProviderFactory.create(config: config)

            var results: [(landmark: CalibrationLandmark, aiPoint: CGPoint, error: Double)] = []
            var annotations: [CanvasAnnotation] = []
            let screenW = screenCapture.displayPointWidth
            let screenH = screenCapture.displayPointHeight

            for landmark in landmarks {
                let prompt = "Click on the \(landmark.name). Output a single click action as JSON. Image is \(imgW)x\(imgH) pixels."
                let messages = [LLMMessage(role: .user, content: prompt, imageData: imgData)]

                do {
                    let response = try await provider.sendMessage(messages)
                    let parsed = ActionParser.parse(response.content)
                    if let firstClick = parsed.actions.first,
                       case .click(let aiX, let aiY) = firstClick {
                        // Map AI coords to display points
                        let displayX: CGFloat
                        let displayY: CGFloat
                        switch resizeMode {
                        case .fullRes:
                            displayX = CGFloat(aiX)
                            displayY = CGFloat(aiY)
                        case .tileAligned:
                            // Must subtract letterbox offset before scaling
                            if let (_, lbInfo) = ImageUtils.resizeToCanvas(cgImage, targetWidth: 1344, targetHeight: 896) {
                                let adjX = CGFloat(aiX) - CGFloat(lbInfo.offsetX)
                                let adjY = CGFloat(aiY) - CGFloat(lbInfo.offsetY)
                                displayX = adjX * CGFloat(screenW) / CGFloat(lbInfo.imageWidth)
                                displayY = adjY * CGFloat(screenH) / CGFloat(lbInfo.imageHeight)
                            } else {
                                displayX = CGFloat(aiX) * CGFloat(screenW) / CGFloat(imgW)
                                displayY = CGFloat(aiY) * CGFloat(screenH) / CGFloat(imgH)
                            }
                        case .fit1280:
                            displayX = CGFloat(aiX) * CGFloat(screenW) / CGFloat(imgW)
                            displayY = CGFloat(aiY) * CGFloat(screenH) / CGFloat(imgH)
                        }

                        let aiPoint = CGPoint(x: displayX, y: displayY)
                        let dx = displayX - landmark.expectedDisplayPoint.x
                        let dy = displayY - landmark.expectedDisplayPoint.y
                        let error = sqrt(dx * dx + dy * dy)

                        results.append((landmark: landmark, aiPoint: aiPoint, error: error))

                        let color: Color = error < 10 ? .green : error < 30 ? .yellow : .red
                        annotations.append(.fromScreenPoint(
                            x: Int(displayX), y: Int(displayY),
                            screenWidth: screenW, screenHeight: screenH,
                            label: "\(landmark.name): \(String(format: "%.0f", error))px",
                            color: color
                        ))

                        Log.info("AI Cal '\(landmark.name)': AI=(\(Int(displayX)),\(Int(displayY))) expected=(\(Int(landmark.expectedDisplayPoint.x)),\(Int(landmark.expectedDisplayPoint.y))) error=\(String(format: "%.1f", error))px")
                    }
                } catch {
                    Log.error("AI Cal '\(landmark.name)' failed: \(error.localizedDescription)")
                }
            }

            let avgError = results.isEmpty ? 0 : results.map(\.error).reduce(0, +) / Double(results.count)
            let avgDeltaX = results.isEmpty ? 0 : results.map { $0.aiPoint.x - $0.landmark.expectedDisplayPoint.x }.reduce(0, +) / CGFloat(results.count)
            let avgDeltaY = results.isEmpty ? 0 : results.map { $0.aiPoint.y - $0.landmark.expectedDisplayPoint.y }.reduce(0, +) / CGFloat(results.count)

            Log.info("AI Calibration complete: avg error=\(String(format: "%.1f", avgError))px, avg offset=(\(String(format: "%.1f", avgDeltaX)), \(String(format: "%.1f", avgDeltaY)))")

            await MainActor.run {
                aiCalibrationResult = results
                overlayAnnotations = annotations
                showOverlay = true
                isCalibrating = false
            }
        }
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

    /// Reverse calibration: draw markers on screenshot at known positions, ask AI to click them
    private func runReverseCalibration() {
        guard screenCapture.isCapturing, screenCapture.displayPointWidth > 0 else {
            Log.error("Cannot run reverse calibration - capture not running")
            return
        }
        guard let sessionID = sessionManager.activeSessionID,
              let session = sessionManager.sessions.first(where: { $0.id == sessionID }) else {
            Log.error("Reverse calibration: no active session")
            return
        }
        isCalibrating = true

        Task {
            guard let frame = screenCapture.currentFrame,
                  let cgImage = frame.image else {
                Log.error("Reverse calibration: no frame available")
                await MainActor.run { isCalibrating = false }
                return
            }

            let displayW = screenCapture.displayPointWidth
            let displayH = screenCapture.displayPointHeight
            let margin = 100

            // 5 test positions spread across the screen (in display points)
            let testPoints: [(String, CGPoint)] = [
                ("Center", CGPoint(x: displayW / 2, y: displayH / 2)),
                ("Top-Left", CGPoint(x: margin, y: margin)),
                ("Top-Right", CGPoint(x: displayW - margin, y: margin)),
                ("Bottom-Left", CGPoint(x: margin, y: displayH - margin)),
                ("Bottom-Right", CGPoint(x: displayW - margin, y: displayH - margin)),
            ]

            let config = LLMProviderConfig(
                providerType: session.providerType,
                apiKey: session.apiKey,
                model: session.model,
                systemPrompt: ActionSystemPrompt.defaultPrompt + ActionSystemPrompt.coordinateSystemSection,
                maxTokens: 256,
                temperature: 0.3
            )
            let provider = LLMProviderFactory.create(config: config)

            var results: [CalibrationPoint] = []
            var annotations: [CanvasAnnotation] = []

            for (label, displayPt) in testPoints {
                // Convert display point to image pixel coordinates for drawing the marker
                let markerImage: CGImage?
                let imgW: Int
                let imgH: Int
                let markerPixelX: Int
                let markerPixelY: Int

                switch resizeMode {
                case .fullRes:
                    // Display points to pixel coords (image may be Retina)
                    let scaleX = CGFloat(cgImage.width) / CGFloat(displayW)
                    let scaleY = CGFloat(cgImage.height) / CGFloat(displayH)
                    markerPixelX = Int(CGFloat(displayPt.x) * scaleX)
                    markerPixelY = Int(CGFloat(displayPt.y) * scaleY)
                    markerImage = ImageUtils.drawMarker(on: cgImage, atX: markerPixelX, atY: markerPixelY)
                    imgW = cgImage.width
                    imgH = cgImage.height

                case .tileAligned:
                    if let (canvas, info) = ImageUtils.resizeToCanvas(cgImage, targetWidth: 1344, targetHeight: 896) {
                        // Optionally draw grid before marker so AI has tile anchors
                        let baseCanvas = useGridOverlay ? (ImageUtils.drawGrid(on: canvas) ?? canvas) : canvas
                        // Display point -> position within the letterboxed canvas
                        markerPixelX = info.offsetX + Int(CGFloat(displayPt.x) * CGFloat(info.imageWidth) / CGFloat(displayW))
                        markerPixelY = info.offsetY + Int(CGFloat(displayPt.y) * CGFloat(info.imageHeight) / CGFloat(displayH))
                        markerImage = ImageUtils.drawMarker(on: baseCanvas, atX: markerPixelX, atY: markerPixelY)
                        imgW = info.canvasWidth
                        imgH = info.canvasHeight
                    } else {
                        continue
                    }

                case .fit1280:
                    if let resized = ImageUtils.resize(cgImage, maxDimension: 1280) {
                        let scaleX = CGFloat(resized.width) / CGFloat(displayW)
                        let scaleY = CGFloat(resized.height) / CGFloat(displayH)
                        markerPixelX = Int(CGFloat(displayPt.x) * scaleX)
                        markerPixelY = Int(CGFloat(displayPt.y) * scaleY)
                        markerImage = ImageUtils.drawMarker(on: resized, atX: markerPixelX, atY: markerPixelY)
                        imgW = resized.width
                        imgH = resized.height
                    } else {
                        continue
                    }
                }

                guard let marked = markerImage,
                      let imgData = ImageUtils.pngData(from: marked) else { continue }

                let gridInfo = useGridOverlay && resizeMode == .tileAligned
                    ? " The image has a 3x2 grid overlay (A1-A3 top, B1-B3 bottom, each 448x448px). You may use click_tile for better accuracy: {\"action\": \"click_tile\", \"tile\": \"<id>\", \"x\": <local_x>, \"y\": <local_y>} where x,y are local coords within the 448x448 tile."
                    : ""
                let prompt = "There is a red crosshair marker drawn on this screenshot. Click on the exact center of the red crosshair. Output a single click action as JSON. Image is \(imgW)x\(imgH) pixels. Coordinates must be in range x: [0, \(imgW - 1)], y: [0, \(imgH - 1)]. Origin (0,0) is the top-left corner.\(gridInfo)"
                let messages = [LLMMessage(role: .user, content: prompt, imageData: imgData)]

                do {
                    let response = try await provider.sendMessage(messages)
                    let parsed = ActionParser.parse(response.content)

                    // Extract global image coordinates from either click or click_tile
                    let aiCoords: (x: Int, y: Int)?
                    if let first = parsed.actions.first {
                        switch first {
                        case .click(let x, let y):
                            aiCoords = (x, y)
                        case .clickTile(let tile, let lx, let ly):
                            let tileOffsets: [String: (x: Int, y: Int)] = [
                                "A1": (0, 0), "A2": (448, 0), "A3": (896, 0),
                                "B1": (0, 448), "B2": (448, 448), "B3": (896, 448),
                            ]
                            if let offset = tileOffsets[tile.uppercased()] {
                                aiCoords = (offset.x + lx, offset.y + ly)
                                Log.info("Reverse Cal: click_tile \(tile) local (\(lx),\(ly)) -> global (\(aiCoords!.x),\(aiCoords!.y))")
                            } else {
                                aiCoords = nil
                            }
                        default:
                            aiCoords = nil
                        }
                    } else {
                        aiCoords = nil
                    }

                    if let (aiX, aiY) = aiCoords {
                        // Compare AI response to where we actually drew the marker (in image pixels)
                        let errorPixels = sqrt(pow(Double(aiX - markerPixelX), 2) + pow(Double(aiY - markerPixelY), 2))

                        let aiPoint = CGPoint(x: aiX, y: aiY)
                        let targetPoint = CGPoint(x: markerPixelX, y: markerPixelY)

                        results.append(CalibrationPoint(
                            label: label,
                            target: targetPoint,
                            actual: aiPoint,
                            errorPixels: errorPixels
                        ))

                        // Show annotation at the marker position in image-pixel space
                        let color: Color = errorPixels < 10 ? .green : errorPixels < 30 ? .yellow : .red
                        annotations.append(.fromScreenPoint(
                            x: markerPixelX, y: markerPixelY,
                            screenWidth: imgW, screenHeight: imgH,
                            label: "\(label) target", color: .blue
                        ))
                        annotations.append(.fromScreenPoint(
                            x: aiX, y: aiY,
                            screenWidth: imgW, screenHeight: imgH,
                            label: "\(label): \(String(format: "%.0f", errorPixels))px", color: color
                        ))

                        Log.info("Reverse Cal '\(label)': marker=(\(markerPixelX),\(markerPixelY)) AI=(\(aiX),\(aiY)) error=\(String(format: "%.1f", errorPixels))px")
                    }
                } catch {
                    Log.error("Reverse Cal '\(label)' failed: \(error.localizedDescription)")
                }
            }

            let avgError = results.isEmpty ? 0 : results.map(\.errorPixels).reduce(0, +) / Double(results.count)
            let maxError = results.map(\.errorPixels).max() ?? 0
            Log.info("Reverse Calibration complete: avg=\(String(format: "%.1f", avgError))px max=\(String(format: "%.1f", maxError))px (\(results.count)/\(testPoints.count) points)")

            await MainActor.run {
                overlayAnnotations = annotations
                showOverlay = true
                isCalibrating = false
            }
        }
    }

    /// Compute the resized image dimensions for the current resize mode
    private func resizedImageDimensions(frame: CapturedFrame) -> (Int, Int) {
        switch resizeMode {
        case .fullRes:
            return (frame.width, frame.height)
        case .tileAligned:
            return (1344, 896)
        case .fit1280:
            let w = frame.width
            let h = frame.height
            let maxDim = 1280
            let maxCurrent = max(w, h)
            if maxCurrent <= maxDim {
                return (w, h)
            }
            let scale = CGFloat(maxDim) / CGFloat(maxCurrent)
            return (Int(CGFloat(w) * scale), Int(CGFloat(h) * scale))
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
    @Binding var resizeMode: ResizeMode
    @Binding var useSmartClick: Bool
    @Binding var useRefineClicks: Bool
    @Binding var useGridOverlay: Bool
    @Binding var excludeOwnWindows: Bool
    @Binding var excludeTerminalWindows: Bool
    let isCalibrating: Bool
    let onToggleCapture: () -> Void
    let onSettings: () -> Void
    let onExportScreenshot: () -> Void
    let onCalibrate: () -> Void
    let onAICalibrate: () -> Void
    let onReverseCal: () -> Void
    let provider: LLMProviderType
    let model: String

    var body: some View {
        VStack(spacing: 4) {
            // Top row: capture, resize, provider
            HStack(spacing: 8) {
                Button(action: onToggleCapture) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isCapturing ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        Text(isCapturing ? "Stop" : "Start")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Picker("", selection: $resizeMode) {
                    ForEach(ResizeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

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
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Export screenshot")
                .disabled(!isCapturing)

                Button(action: onSettings) {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }

            // Bottom row: toggles, exclusions menu, calibration menu
            HStack(spacing: 8) {
                Toggle("Overlay", isOn: $showOverlay)
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                Toggle("Smart Click", isOn: $useSmartClick)
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                Toggle("Refine", isOn: $useRefineClicks)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Pre-execution refinement: crop around click target and re-ask AI before clicking")

                Toggle("Grid", isOn: $useGridOverlay)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help("Draw 3x2 tile grid on screenshots (tile-aligned mode only)")

                Toggle("Hide Preview", isOn: $hidePreview)
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                Divider().frame(height: 14)

                Menu {
                    Toggle("Exclude This App", isOn: $excludeOwnWindows)
                    Toggle("Exclude Terminal", isOn: $excludeTerminalWindows)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 10))
                        Text("Exclude")
                            .font(.system(size: 11))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Divider().frame(height: 14)

                Menu {
                    Button("Mechanical Calibrate") { onCalibrate() }
                    Button("AI Landmark Cal") { onAICalibrate() }
                    Button("Marker Cal (Reverse)") { onReverseCal() }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "scope")
                            .font(.system(size: 10))
                        Text(isCalibrating ? "Calibrating..." : "Calibrate")
                            .font(.system(size: 11))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(!isCapturing || isCalibrating)

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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

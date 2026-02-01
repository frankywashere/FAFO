import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool

    @Binding var selectedProvider: LLMProviderType
    @Binding var apiKey: String
    @Binding var selectedModel: String
    @Binding var systemPrompt: String
    @Binding var maxTokens: Int
    @Binding var temperature: Double

    // Stored API keys per provider
    @AppStorage("apiKey_openai") private var openaiKey = ""
    @AppStorage("apiKey_anthropic") private var anthropicKey = ""
    @AppStorage("apiKey_gemini") private var geminiKey = ""
    @AppStorage("apiKey_grok") private var grokKey = ""

    @State private var isValidating = false
    @State private var validationResult: String?

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Provider Selection
                    GroupBox("LLM Provider") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Provider", selection: $selectedProvider) {
                                ForEach(LLMProviderType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedProvider) { _, newValue in
                                loadKeyForProvider(newValue)
                                selectedModel = newValue.defaultModels.first ?? ""
                            }

                            // API Key
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Key")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    StyledAppKitSecureField(
                                        placeholder: "Enter \(selectedProvider.displayName) API key",
                                        text: $apiKey
                                    )
                                    .onChange(of: apiKey) { _, newValue in
                                        saveKeyForProvider(selectedProvider, key: newValue)
                                    }

                                    Button(action: validateKey) {
                                        if isValidating {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "checkmark.circle")
                                        }
                                    }
                                    .disabled(apiKey.isEmpty || isValidating)
                                    .help("Validate API key")
                                }

                                if let result = validationResult {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(result.contains("Valid") ? .green : .red)
                                }
                            }

                            // Model Selection
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Model")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Model", selection: $selectedModel) {
                                    ForEach(selectedProvider.defaultModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                        .padding(8)
                    }

                    // System Prompt
                    GroupBox("System Prompt") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextEditor(text: $systemPrompt)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(height: 100)
                                .border(Color.gray.opacity(0.3))

                            Button("Reset to Default") {
                                systemPrompt = ActionSystemPrompt.defaultPrompt
                            }
                            .controlSize(.small)
                        }
                        .padding(8)
                    }

                    // Generation Settings
                    GroupBox("Generation Settings") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Max Tokens:")
                                    .font(.caption)
                                Spacer()
                                TextField("", value: $maxTokens, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Temperature: \(String(format: "%.2f", temperature))")
                                        .font(.caption)
                                    Spacer()
                                }
                                Slider(value: $temperature, in: 0...2, step: 0.05)
                            }
                        }
                        .padding(8)
                    }

                    // Quick API Key Setup
                    GroupBox("Quick Setup - Saved API Keys") {
                        VStack(alignment: .leading, spacing: 8) {
                            APIKeyRow(label: "OpenAI", key: $openaiKey, placeholder: "sk-...")
                            APIKeyRow(label: "Anthropic", key: $anthropicKey, placeholder: "sk-ant-...")
                            APIKeyRow(label: "Gemini", key: $geminiKey, placeholder: "AI...")
                            APIKeyRow(label: "Grok", key: $grokKey, placeholder: "xai-...")
                        }
                        .padding(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 650)
        .onAppear {
            loadKeyForProvider(selectedProvider)
        }
    }

    private func loadKeyForProvider(_ provider: LLMProviderType) {
        switch provider {
        case .openai: apiKey = openaiKey
        case .anthropic: apiKey = anthropicKey
        case .gemini: apiKey = geminiKey
        case .grok: apiKey = grokKey
        }
    }

    private func saveKeyForProvider(_ provider: LLMProviderType, key: String) {
        switch provider {
        case .openai: openaiKey = key
        case .anthropic: anthropicKey = key
        case .gemini: geminiKey = key
        case .grok: grokKey = key
        }
    }

    private func validateKey() {
        isValidating = true
        validationResult = nil

        let config = LLMProviderConfig(providerType: selectedProvider, apiKey: apiKey, model: selectedModel)
        let provider = LLMProviderFactory.create(config: config)

        Task {
            do {
                let valid = try await provider.validateAPIKey()
                await MainActor.run {
                    validationResult = valid ? "Valid API key" : "Invalid API key"
                    isValidating = false
                }
            } catch {
                await MainActor.run {
                    validationResult = "Error: \(error.localizedDescription)"
                    isValidating = false
                }
            }
        }
    }
}

struct APIKeyRow: View {
    let label: String
    @Binding var key: String
    let placeholder: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 70, alignment: .leading)
            StyledAppKitSecureField(placeholder: placeholder, text: $key)
            Circle()
                .fill(key.isEmpty ? Color.gray : Color.green)
                .frame(width: 8, height: 8)
        }
    }
}

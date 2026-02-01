import Foundation

// MARK: - LLM Provider Protocol

enum LLMProviderType: String, CaseIterable, Codable, Identifiable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Gemini"
    case grok = "Grok"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var defaultModels: [String] {
        switch self {
        case .openai:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"]
        case .anthropic:
            return ["claude-sonnet-4-5-20250929", "claude-haiku-4-5-20251001", "claude-opus-4-5-20251101"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash"]
        case .grok:
            return ["grok-4-1-fast", "grok-4", "grok-4-fast", "grok-3"]
        }
    }

    var supportsVision: Bool { true }
}

struct LLMMessage: Codable {
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    let role: Role
    let content: String
    let imageData: Data?

    init(role: Role, content: String, imageData: Data? = nil) {
        self.role = role
        self.content = content
        self.imageData = imageData
    }
}

struct LLMResponse {
    let content: String
    let model: String
    let tokensUsed: Int?
    let finishReason: String?
}

enum LLMError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse(String)
    case rateLimited
    case serverError(Int, String)
    case imageEncodingFailed
    case streamingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Invalid or missing API key"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let msg): return "Invalid response: \(msg)"
        case .rateLimited: return "Rate limited - please wait and retry"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .imageEncodingFailed: return "Failed to encode image data"
        case .streamingError(let msg): return "Streaming error: \(msg)"
        }
    }
}

struct LLMProviderConfig: Codable {
    var providerType: LLMProviderType
    var apiKey: String
    var model: String
    var systemPrompt: String
    var maxTokens: Int
    var temperature: Double

    init(providerType: LLMProviderType, apiKey: String, model: String? = nil,
         systemPrompt: String = ActionSystemPrompt.defaultPrompt,
         maxTokens: Int = 4096, temperature: Double = 0.7) {
        self.providerType = providerType
        self.apiKey = apiKey
        self.model = model ?? providerType.defaultModels.first ?? ""
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

protocol LLMProvider: AnyObject {
    var config: LLMProviderConfig { get set }

    func sendMessage(_ messages: [LLMMessage]) async throws -> LLMResponse
    func sendMessageStreaming(_ messages: [LLMMessage], onToken: @escaping (String) -> Void) async throws -> LLMResponse
    func validateAPIKey() async throws -> Bool
}

extension LLMProvider {
    func sendMessageStreaming(_ messages: [LLMMessage], onToken: @escaping (String) -> Void) async throws -> LLMResponse {
        return try await sendMessage(messages)
    }
}

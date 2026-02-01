import Foundation

enum LLMProviderFactory {
    static func create(config: LLMProviderConfig) -> LLMProvider {
        switch config.providerType {
        case .openai, .grok:
            return OpenAIProvider(config: config)
        case .anthropic:
            return AnthropicProvider(config: config)
        case .gemini:
            return GeminiProvider(config: config)
        }
    }

    static func create(type: LLMProviderType, apiKey: String, model: String? = nil) -> LLMProvider {
        let config = LLMProviderConfig(providerType: type, apiKey: apiKey, model: model)
        return create(config: config)
    }
}

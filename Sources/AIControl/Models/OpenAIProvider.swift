import Foundation

// OpenAI-compatible provider (also used for Grok/xAI)
final class OpenAIProvider: LLMProvider {
    var config: LLMProviderConfig
    private let session: URLSession

    private var baseURL: String {
        switch config.providerType {
        case .grok:
            return "https://api.x.ai/v1"
        case .openai:
            return "https://api.openai.com/v1"
        default:
            return "https://api.openai.com/v1"
        }
    }

    init(config: LLMProviderConfig) {
        self.config = config
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 120
        sessionConfig.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: sessionConfig)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func validateAPIKey() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/models") else {
            throw LLMError.invalidResponse("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        if httpResponse.statusCode >= 500 {
            throw LLMError.serverError(httpResponse.statusCode, "Server error during validation")
        }
        return httpResponse.statusCode == 200
    }

    func sendMessage(_ messages: [LLMMessage]) async throws -> LLMResponse {
        let request = try buildRequest(messages: messages, stream: false)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse("No HTTP response")
        }

        if httpResponse.statusCode == 429 {
            throw LLMError.rateLimited
        }

        if httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.serverError(httpResponse.statusCode, body)
        }

        return try parseResponse(data)
    }

    func sendMessageStreaming(_ messages: [LLMMessage], onToken: @escaping (String) -> Void) async throws -> LLMResponse {
        let request = try buildRequest(messages: messages, stream: true)

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse("No HTTP response")
        }

        if httpResponse.statusCode >= 400 {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let body = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 429 { throw LLMError.rateLimited }
            throw LLMError.serverError(httpResponse.statusCode, body)
        }

        var fullContent = ""
        var model = config.model
        var finishReason: String?
        var tokensUsed: Int?

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            if jsonString == "[DONE]" { break }

            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            if let m = json["model"] as? String { model = m }

            // Extract usage from streaming (when include_usage is set)
            if let usage = json["usage"] as? [String: Any],
               let total = usage["total_tokens"] as? Int {
                tokensUsed = total
            }

            guard let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first else { continue }

            if let delta = firstChoice["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                fullContent += content
                onToken(content)
            }

            if let fr = firstChoice["finish_reason"] as? String {
                finishReason = fr
            }
        }

        return LLMResponse(content: fullContent, model: model, tokensUsed: tokensUsed, finishReason: finishReason)
    }

    // MARK: - Private helpers

    private func buildRequest(messages: [LLMMessage], stream: Bool) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMError.invalidResponse("Invalid URL for chat completions")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var apiMessages: [[String: Any]] = []

        if !config.systemPrompt.isEmpty {
            apiMessages.append([
                "role": "system",
                "content": config.systemPrompt
            ])
        }

        for msg in messages {
            if let imageData = msg.imageData {
                let base64 = imageData.base64EncodedString()
                let content: [[String: Any]] = [
                    [
                        "type": "text",
                        "text": msg.content
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/png;base64,\(base64)",
                            "detail": "high"
                        ]
                    ]
                ]
                apiMessages.append([
                    "role": msg.role.rawValue,
                    "content": content
                ])
            } else {
                apiMessages.append([
                    "role": msg.role.rawValue,
                    "content": msg.content
                ])
            }
        }

        let temp = min(max(config.temperature, 0), 2.0)

        var body: [String: Any] = [
            "model": config.model,
            "messages": apiMessages,
            "max_tokens": config.maxTokens,
            "temperature": temp,
            "stream": stream
        ]

        if stream {
            body["stream_options"] = ["include_usage": true]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse("Failed to parse JSON")
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw LLMError.invalidResponse("Missing choices/message/content: \(body)")
        }

        let model = json["model"] as? String ?? config.model
        let finishReason = firstChoice["finish_reason"] as? String

        var tokensUsed: Int?
        if let usage = json["usage"] as? [String: Any],
           let total = usage["total_tokens"] as? Int {
            tokensUsed = total
        }

        return LLMResponse(content: content, model: model, tokensUsed: tokensUsed, finishReason: finishReason)
    }
}

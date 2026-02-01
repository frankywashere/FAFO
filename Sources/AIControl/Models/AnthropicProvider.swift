import Foundation

final class AnthropicProvider: LLMProvider {
    var config: LLMProviderConfig
    private let session: URLSession
    private let baseURL = "https://api.anthropic.com/v1"
    private let apiVersion = "2023-06-01"

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
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw LLMError.invalidResponse("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 10,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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

        if httpResponse.statusCode == 429 { throw LLMError.rateLimited }

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
        var tokensUsed: Int?
        var finishReason: String?

        for try await line in bytes.lines {
            if line.hasPrefix("event: ") {
                let eventType = String(line.dropFirst(7))
                if eventType == "message_stop" { break }
                continue
            }

            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))

            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            let type = json["type"] as? String ?? ""

            switch type {
            case "message_start":
                if let message = json["message"] as? [String: Any],
                   let m = message["model"] as? String {
                    model = m
                }

            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    fullContent += text
                    onToken(text)
                }

            case "message_delta":
                if let delta = json["delta"] as? [String: Any],
                   let sr = delta["stop_reason"] as? String {
                    finishReason = sr
                }
                if let usage = json["usage"] as? [String: Any],
                   let outputTokens = usage["output_tokens"] as? Int {
                    tokensUsed = outputTokens
                }

            default:
                break
            }
        }

        return LLMResponse(content: fullContent, model: model, tokensUsed: tokensUsed, finishReason: finishReason ?? "end_turn")
    }

    // MARK: - Private helpers

    private func buildRequest(messages: [LLMMessage], stream: Bool) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw LLMError.invalidResponse("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "content-type")

        var apiMessages: [[String: Any]] = []

        for msg in messages {
            if msg.role == .system { continue }

            if let imageData = msg.imageData {
                let base64 = imageData.base64EncodedString()
                let content: [[String: Any]] = [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/png",
                            "data": base64
                        ]
                    ],
                    [
                        "type": "text",
                        "text": msg.content
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

        // If no user messages after filtering, add a placeholder
        if apiMessages.isEmpty {
            apiMessages.append(["role": "user", "content": "Hello"])
        }

        let systemPrompt = config.systemPrompt.isEmpty ? nil : config.systemPrompt
        let temp = min(max(config.temperature, 0), 1.0) // Anthropic max is 1.0

        var body: [String: Any] = [
            "model": config.model,
            "messages": apiMessages,
            "max_tokens": config.maxTokens,
            "temperature": temp,
            "stream": stream
        ]

        if let sys = systemPrompt {
            body["system"] = sys
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse("Failed to parse JSON")
        }

        guard let content = json["content"] as? [[String: Any]] else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw LLMError.invalidResponse("Missing content: \(body)")
        }

        let textBlocks = content.compactMap { block -> String? in
            guard block["type"] as? String == "text" else { return nil }
            return block["text"] as? String
        }

        let fullContent = textBlocks.joined()
        let model = json["model"] as? String ?? config.model
        let stopReason = json["stop_reason"] as? String

        var tokensUsed: Int?
        if let usage = json["usage"] as? [String: Any],
           let input = usage["input_tokens"] as? Int,
           let output = usage["output_tokens"] as? Int {
            tokensUsed = input + output
        }

        return LLMResponse(content: fullContent, model: model, tokensUsed: tokensUsed, finishReason: stopReason)
    }
}

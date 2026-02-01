import Foundation

final class GeminiProvider: LLMProvider {
    var config: LLMProviderConfig
    private let session: URLSession
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"

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
        guard var components = URLComponents(string: "\(baseURL)/models") else {
            throw LLMError.invalidResponse("Invalid URL")
        }
        components.queryItems = [URLQueryItem(name: "key", value: config.apiKey)]
        guard let url = components.url else {
            throw LLMError.invalidResponse("Invalid URL")
        }
        var request = URLRequest(url: url)
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
        let model = config.model
        var finishReason: String?
        var tokensUsed: Int?

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))

            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first else { continue }

            // Extract finish reason
            if let fr = firstCandidate["finishReason"] as? String {
                finishReason = fr
            }

            // Extract tokens
            if let usageMetadata = json["usageMetadata"] as? [String: Any],
               let total = usageMetadata["totalTokenCount"] as? Int {
                tokensUsed = total
            }

            if let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String {
                        fullContent += text
                        onToken(text)
                    }
                }
            }
        }

        return LLMResponse(content: fullContent, model: model, tokensUsed: tokensUsed, finishReason: finishReason)
    }

    // MARK: - Private helpers

    private func buildRequest(messages: [LLMMessage], stream: Bool) throws -> URLRequest {
        let action = stream ? "streamGenerateContent" : "generateContent"
        guard var components = URLComponents(string: "\(baseURL)/models/\(config.model):\(action)") else {
            throw LLMError.invalidResponse("Invalid URL")
        }
        var queryItems = [URLQueryItem(name: "key", value: config.apiKey)]
        if stream {
            queryItems.append(URLQueryItem(name: "alt", value: "sse"))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw LLMError.invalidResponse("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = []

        for msg in messages {
            if msg.role == .system { continue }

            let role = msg.role == .assistant ? "model" : "user"
            var parts: [[String: Any]] = []

            if let imageData = msg.imageData {
                let base64 = imageData.base64EncodedString()
                parts.append([
                    "inline_data": [
                        "mime_type": "image/png",
                        "data": base64
                    ]
                ])
            }

            parts.append(["text": msg.content])

            contents.append([
                "role": role,
                "parts": parts
            ])
        }

        // If no contents after filtering, add a placeholder
        if contents.isEmpty {
            contents.append(["role": "user", "parts": [["text": "Hello"]]])
        }

        let temp = min(max(config.temperature, 0), 2.0)

        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "maxOutputTokens": config.maxTokens,
                "temperature": temp
            ]
        ]

        if !config.systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [["text": config.systemPrompt]]
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(_ data: Data) throws -> LLMResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse("Failed to parse JSON")
        }

        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw LLMError.invalidResponse("Missing candidates/content/parts: \(body)")
        }

        let textParts = parts.compactMap { $0["text"] as? String }
        let fullContent = textParts.joined()
        let finishReason = firstCandidate["finishReason"] as? String

        var tokensUsed: Int?
        if let usageMetadata = json["usageMetadata"] as? [String: Any],
           let total = usageMetadata["totalTokenCount"] as? Int {
            tokensUsed = total
        }

        return LLMResponse(content: fullContent, model: config.model, tokensUsed: tokensUsed, finishReason: finishReason)
    }
}

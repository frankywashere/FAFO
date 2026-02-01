#!/usr/bin/env swift

// Standalone test for LLM provider connectivity
// Usage: swift test_llm_providers.swift [provider] [api_key]
// Example: swift test_llm_providers.swift grok xai-your-key-here

import Foundation

// MARK: - Test OpenAI-compatible API (OpenAI + Grok)

func testOpenAICompatible(baseURL: String, apiKey: String, model: String, label: String) async {
    print("\n--- Testing \(label) ---")
    print("Base URL: \(baseURL)")
    print("Model: \(model)")

    let url = URL(string: "\(baseURL)/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 60

    let body: [String: Any] = [
        "model": model,
        "messages": [
            ["role": "user", "content": "Say 'hello' in exactly one word."]
        ],
        "max_tokens": 50,
        "temperature": 0
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        print("Status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                print("Response: \(content)")
                print("PASS")
            } else {
                print("Failed to parse response")
                print("Raw: \(String(data: data, encoding: .utf8) ?? "nil")")
                print("FAIL")
            }
        } else {
            print("Error: \(String(data: data, encoding: .utf8) ?? "nil")")
            print("FAIL")
        }
    } catch {
        print("Error: \(error)")
        print("FAIL")
    }
}

// MARK: - Test Anthropic API

func testAnthropic(apiKey: String, model: String) async {
    print("\n--- Testing Anthropic ---")
    print("Model: \(model)")

    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.addValue("application/json", forHTTPHeaderField: "content-type")
    request.timeoutInterval = 60

    let body: [String: Any] = [
        "model": model,
        "max_tokens": 50,
        "messages": [
            ["role": "user", "content": "Say 'hello' in exactly one word."]
        ]
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        print("Status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                print("Response: \(text)")
                print("PASS")
            } else {
                print("Failed to parse response")
                print("FAIL")
            }
        } else {
            print("Error: \(String(data: data, encoding: .utf8) ?? "nil")")
            print("FAIL")
        }
    } catch {
        print("Error: \(error)")
        print("FAIL")
    }
}

// MARK: - Test Gemini API

func testGemini(apiKey: String, model: String) async {
    print("\n--- Testing Gemini ---")
    print("Model: \(model)")

    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 60

    let body: [String: Any] = [
        "contents": [
            ["role": "user", "parts": [["text": "Say 'hello' in exactly one word."]]]
        ],
        "generationConfig": ["maxOutputTokens": 50, "temperature": 0]
    ]

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        print("Status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                print("Response: \(text)")
                print("PASS")
            } else {
                print("Failed to parse response")
                print("FAIL")
            }
        } else {
            print("Error: \(String(data: data, encoding: .utf8) ?? "nil")")
            print("FAIL")
        }
    } catch {
        print("Error: \(error)")
        print("FAIL")
    }
}

// MARK: - Main

let args = CommandLine.arguments

print("=== LLM Provider Test Suite ===")
print("Usage: swift test_llm_providers.swift [provider] [api_key]")
print("Providers: grok, openai, anthropic, gemini, all")
print("")

if args.count >= 3 {
    let provider = args[1].lowercased()
    let apiKey = args[2]

    await {
        switch provider {
        case "grok":
            await testOpenAICompatible(baseURL: "https://api.x.ai/v1", apiKey: apiKey, model: "grok-4-1-fast", label: "Grok (xAI)")
        case "openai":
            await testOpenAICompatible(baseURL: "https://api.openai.com/v1", apiKey: apiKey, model: "gpt-4o-mini", label: "OpenAI")
        case "anthropic":
            await testAnthropic(apiKey: apiKey, model: "claude-sonnet-4-5-20250929")
        case "gemini":
            await testGemini(apiKey: apiKey, model: "gemini-2.0-flash")
        case "all":
            print("Testing all providers requires individual keys.")
            print("Run each provider separately.")
        default:
            print("Unknown provider: \(provider)")
        }
    }()
} else {
    print("No arguments provided. Please specify a provider and API key.")
    print("Example: swift test_llm_providers.swift grok xai-your-key")
}

print("\n=== Done ===")

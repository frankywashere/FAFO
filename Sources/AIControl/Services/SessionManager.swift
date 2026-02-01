import Foundation
import SwiftUI

struct AISession: Identifiable, Codable {
    let id: UUID
    var name: String
    var providerType: LLMProviderType
    var model: String
    var apiKey: String
    var systemPrompt: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool

    init(name: String, providerType: LLMProviderType, model: String, apiKey: String,
         systemPrompt: String = ActionSystemPrompt.defaultPrompt) {
        self.id = UUID()
        self.name = name
        self.providerType = providerType
        self.model = model
        self.apiKey = apiKey
        self.systemPrompt = systemPrompt
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let hasImage: Bool
    var imageDataBase64: String?

    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
        case error
    }

    init(role: MessageRole, content: String, hasImage: Bool = false, imageData: Data? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.hasImage = hasImage
        self.imageDataBase64 = imageData?.base64EncodedString()
    }
}

struct SessionRecordEntry: Codable {
    let timestamp: Date
    let action: String
    let details: String
    let screenshotBase64: String?
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var sessions: [AISession] = []
    @Published var activeSessionID: UUID?
    @Published var isRecording = false

    private var recordings: [UUID: [SessionRecordEntry]] = [:]
    private let saveURL: URL

    var activeSession: AISession? {
        get { sessions.first { $0.id == activeSessionID } }
        set {
            if let newValue = newValue, let idx = sessions.firstIndex(where: { $0.id == newValue.id }) {
                sessions[idx] = newValue
            }
        }
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("AIControl", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.saveURL = appDir.appendingPathComponent("sessions.json")
        loadSessions()
    }

    func createSession(name: String, providerType: LLMProviderType, model: String, apiKey: String, systemPrompt: String = ActionSystemPrompt.defaultPrompt) -> AISession {
        let session = AISession(name: name, providerType: providerType, model: model, apiKey: apiKey, systemPrompt: systemPrompt)
        sessions.append(session)
        activeSessionID = session.id
        saveSessions()
        return session
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        recordings.removeValue(forKey: id)
        if activeSessionID == id {
            activeSessionID = sessions.first?.id
        }
        saveSessions()
    }

    func switchSession(_ id: UUID) {
        activeSessionID = id
    }

    func addMessage(to sessionID: UUID, message: ChatMessage) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[idx].messages.append(message)
        sessions[idx].updatedAt = Date()

        if isRecording {
            let entry = SessionRecordEntry(
                timestamp: Date(),
                action: "message_\(message.role.rawValue)",
                details: message.content,
                screenshotBase64: message.imageDataBase64
            )
            recordings[sessionID, default: []].append(entry)
        }

        saveSessions()
    }

    func clearMessages(for sessionID: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[idx].messages = []
        sessions[idx].updatedAt = Date()
        saveSessions()
    }

    // MARK: - Recording

    func startRecording(sessionID: UUID) {
        recordings[sessionID] = []
        isRecording = true
    }

    func stopRecording(sessionID: UUID) {
        isRecording = false
    }

    func getRecording(sessionID: UUID) -> [SessionRecordEntry] {
        return recordings[sessionID] ?? []
    }

    func recordAction(sessionID: UUID, action: String, details: String, screenshot: Data? = nil) {
        guard isRecording else { return }
        let entry = SessionRecordEntry(
            timestamp: Date(),
            action: action,
            details: details,
            screenshotBase64: screenshot?.base64EncodedString()
        )
        recordings[sessionID, default: []].append(entry)
    }

    // MARK: - Export

    func exportSession(_ sessionID: UUID) -> Data? {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(session)
    }

    func exportRecording(_ sessionID: UUID) -> Data? {
        guard let recording = recordings[sessionID] else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(recording)
    }

    // MARK: - Persistence

    private func saveSessions() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(sessions) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }

    func updateSystemPrompt(for sessionID: UUID, prompt: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[idx].systemPrompt = prompt
        sessions[idx].updatedAt = Date()
        saveSessions()
        Log.info("Updated system prompt for session \"\(sessions[idx].name)\"")
    }

    private func loadSessions() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([AISession].self, from: data) {
            sessions = loaded
            activeSessionID = sessions.first?.id

            // Migrate sessions that have outdated system prompts
            let currentPrompt = ActionSystemPrompt.defaultPrompt
            var migrated = false
            for i in sessions.indices {
                if sessions[i].systemPrompt != currentPrompt && !sessions[i].systemPrompt.contains("open_app") {
                    sessions[i].systemPrompt = currentPrompt
                    migrated = true
                    Log.info("Migrated system prompt for session \"\(sessions[i].name)\"")
                }
            }
            if migrated {
                saveSessions()
            }
        }
    }
}

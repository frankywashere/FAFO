import Foundation

struct CommandResult: Codable {
    let success: Bool
    let action: String
    let details: String
    let timestamp: String

    static func success(action: String, details: String) -> CommandResult {
        CommandResult(
            success: true,
            action: action,
            details: details,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }

    static func failure(action: String, error: String) -> CommandResult {
        CommandResult(
            success: false,
            action: action,
            details: error,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }

    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}

struct CaptureResult: Codable {
    let success: Bool
    let screenshotPath: String
    let displayWidth: Int
    let displayHeight: Int
    let cursorX: Int
    let cursorY: Int
    let timestamp: String

    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}

struct CalibrationResult: Codable {
    let success: Bool
    let passed: Bool
    let averageError: Double
    let maxError: Double
    let points: [CalibrationPoint]
    let timestamp: String

    struct CalibrationPoint: Codable {
        let label: String
        let targetX: Int
        let targetY: Int
        let actualX: Int
        let actualY: Int
        let error: Double
    }

    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}

struct StatusResult: Codable {
    let success: Bool
    let displayWidth: Int
    let displayHeight: Int
    let scaleFactor: Double
    let cursorX: Int
    let cursorY: Int
    let accessibilityEnabled: Bool
    let screenRecordingEnabled: Bool
    let timestamp: String

    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}

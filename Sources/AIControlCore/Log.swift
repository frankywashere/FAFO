import Foundation

/// Simple terminal logger with color-coded output for debugging the AI action pipeline.
public enum Log {
    public enum Level: String {
        case info = "INFO"
        case action = "ACTION"
        case error = "ERROR"
        case llm = "LLM"
        case stream = "STREAM"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    public static func info(_ message: String) {
        log(.info, message)
    }

    public static func action(_ message: String) {
        log(.action, message)
    }

    public static func error(_ message: String) {
        log(.error, message)
    }

    public static func llm(_ message: String) {
        log(.llm, message)
    }

    public static func stream(_ message: String) {
        log(.stream, message)
    }

    private static func log(_ level: Level, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let prefix: String
        switch level {
        case .info:   prefix = "\u{001B}[36m[INFO]\u{001B}[0m"    // cyan
        case .action: prefix = "\u{001B}[32m[ACTION]\u{001B}[0m"  // green
        case .error:  prefix = "\u{001B}[31m[ERROR]\u{001B}[0m"   // red
        case .llm:    prefix = "\u{001B}[33m[LLM]\u{001B}[0m"     // yellow
        case .stream: prefix = "\u{001B}[35m[STREAM]\u{001B}[0m"  // magenta
        }
        print("\u{001B}[90m\(timestamp)\u{001B}[0m \(prefix) \(message)")
    }
}

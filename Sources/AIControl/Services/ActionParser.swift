import Foundation
import CoreGraphics

// MARK: - Action Types

enum AIAction: CustomStringConvertible {
    case click(x: Int, y: Int)
    case rightClick(x: Int, y: Int)
    case doubleClick(x: Int, y: Int)
    case moveMouse(x: Int, y: Int)
    case typeText(String)
    case pressKey(String, modifiers: [String])
    case scroll(deltaX: Int, deltaY: Int)
    case drag(fromX: Int, fromY: Int, toX: Int, toY: Int)
    case wait(seconds: Double)
    case screenshot   // request a new screenshot
    case openApp(String) // open an application by name
    case thinking(String)  // AI is explaining what it's doing

    var description: String {
        switch self {
        case .click(let x, let y): return "CLICK at (\(x), \(y))"
        case .rightClick(let x, let y): return "RIGHT_CLICK at (\(x), \(y))"
        case .doubleClick(let x, let y): return "DOUBLE_CLICK at (\(x), \(y))"
        case .moveMouse(let x, let y): return "MOVE_MOUSE to (\(x), \(y))"
        case .typeText(let text): return "TYPE \"\(text.prefix(50))\(text.count > 50 ? "..." : "")\""
        case .pressKey(let key, let mods): return "PRESS_KEY \(key)\(mods.isEmpty ? "" : " + \(mods.joined(separator: "+"))")"
        case .scroll(let dx, let dy): return "SCROLL (dx:\(dx), dy:\(dy))"
        case .drag(let fx, let fy, let tx, let ty): return "DRAG from (\(fx),\(fy)) to (\(tx),\(ty))"
        case .wait(let s): return "WAIT \(s)s"
        case .screenshot: return "SCREENSHOT (requesting new capture)"
        case .openApp(let name): return "OPEN_APP \"\(name)\""
        case .thinking(let t): return "THINKING: \(t.prefix(80))"
        }
    }
}

// MARK: - Parser

enum ActionParser {

    /// Parse LLM response text to extract structured actions.
    /// Supports JSON blocks like: ```json\n{"action": "click", "x": 100, "y": 200}\n```
    /// Also supports inline JSON objects in the text.
    static func parse(_ response: String) -> (actions: [AIAction], explanation: String) {
        var actions: [AIAction] = []
        var explanationParts: [String] = []

        // Try to find JSON blocks first (```json ... ```)
        let jsonBlockPattern = "```(?:json)?\\s*\\n?(\\{[^`]+\\})\\s*```"
        if let regex = try? NSRegularExpression(pattern: jsonBlockPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: response, range: NSRange(response.startIndex..., in: response))
            for match in matches {
                if let range = Range(match.range(at: 1), in: response) {
                    let jsonStr = String(response[range])
                    if let action = parseJSONAction(jsonStr) {
                        actions.append(action)
                    }
                }
            }
        }

        // Also try to find inline JSON objects { "action": ... }
        let inlinePattern = "\\{\\s*\"action\"\\s*:\\s*\"[^\"]+\"[^}]*\\}"
        if let regex = try? NSRegularExpression(pattern: inlinePattern, options: []) {
            let matches = regex.matches(in: response, range: NSRange(response.startIndex..., in: response))
            for match in matches {
                if let range = Range(match.range, in: response) {
                    let jsonStr = String(response[range])
                    // Avoid duplicates from JSON blocks already parsed
                    if let action = parseJSONAction(jsonStr) {
                        let isDuplicate = actions.contains(where: { $0.description == action.description })
                        if !isDuplicate {
                            actions.append(action)
                        }
                    }
                }
            }
        }

        // Extract explanation text (everything that isn't a JSON action block)
        var cleanedResponse = response
        // Remove JSON blocks
        if let regex = try? NSRegularExpression(pattern: "```(?:json)?\\s*\\n?\\{[^`]+\\}\\s*```", options: [.dotMatchesLineSeparators]) {
            cleanedResponse = regex.stringByReplacingMatches(in: cleanedResponse, range: NSRange(cleanedResponse.startIndex..., in: cleanedResponse), withTemplate: "")
        }
        // Remove inline JSON
        if let regex = try? NSRegularExpression(pattern: "\\{\\s*\"action\"\\s*:\\s*\"[^\"]+\"[^}]*\\}", options: []) {
            cleanedResponse = regex.stringByReplacingMatches(in: cleanedResponse, range: NSRange(cleanedResponse.startIndex..., in: cleanedResponse), withTemplate: "")
        }

        let explanation = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explanation.isEmpty {
            explanationParts.append(explanation)
        }

        return (actions, explanationParts.joined(separator: "\n"))
    }

    // MARK: - JSON Action Parsing

    private static func parseJSONAction(_ jsonString: String) -> AIAction? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let actionType = json["action"] as? String else {
            return nil
        }

        switch actionType.lowercased() {
        case "click", "left_click":
            guard let x = json["x"] as? Int, let y = json["y"] as? Int else { return nil }
            return .click(x: x, y: y)

        case "right_click":
            guard let x = json["x"] as? Int, let y = json["y"] as? Int else { return nil }
            return .rightClick(x: x, y: y)

        case "double_click":
            guard let x = json["x"] as? Int, let y = json["y"] as? Int else { return nil }
            return .doubleClick(x: x, y: y)

        case "move", "move_mouse":
            guard let x = json["x"] as? Int, let y = json["y"] as? Int else { return nil }
            return .moveMouse(x: x, y: y)

        case "type", "type_text":
            guard let text = json["text"] as? String else { return nil }
            return .typeText(text)

        case "press_key", "key", "hotkey":
            guard let key = json["key"] as? String else { return nil }
            let modifiers = json["modifiers"] as? [String] ?? []
            return .pressKey(key, modifiers: modifiers)

        case "scroll":
            let dx = json["delta_x"] as? Int ?? json["dx"] as? Int ?? 0
            let dy = json["delta_y"] as? Int ?? json["dy"] as? Int ?? 0
            return .scroll(deltaX: dx, deltaY: dy)

        case "drag":
            guard let fx = json["from_x"] as? Int ?? json["start_x"] as? Int,
                  let fy = json["from_y"] as? Int ?? json["start_y"] as? Int,
                  let tx = json["to_x"] as? Int ?? json["end_x"] as? Int,
                  let ty = json["to_y"] as? Int ?? json["end_y"] as? Int else { return nil }
            return .drag(fromX: fx, fromY: fy, toX: tx, toY: ty)

        case "wait":
            let seconds = json["seconds"] as? Double ?? json["duration"] as? Double ?? 1.0
            return .wait(seconds: seconds)

        case "screenshot", "capture":
            return .screenshot

        case "open_app", "open", "launch":
            guard let name = json["name"] as? String ?? json["app"] as? String else { return nil }
            return .openApp(name)

        default:
            return nil
        }
    }
}

import Foundation
import CoreGraphics

/// Executes AI-parsed actions using InputControlService.
/// Provides logging to terminal for debugging.
@MainActor
final class ActionExecutor: ObservableObject {
    @Published var lastExecutedAction: String = ""
    @Published var actionHistory: [ActionLogEntry] = []
    @Published var isExecuting = false

    private let inputControl: InputControlService

    struct ActionLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let action: String
        let success: Bool
        let detail: String
    }

    init(inputControl: InputControlService) {
        self.inputControl = inputControl
    }

    /// Execute a list of actions sequentially
    func execute(actions: [AIAction]) async {
        guard !actions.isEmpty else { return }
        isExecuting = true

        for action in actions {
            Log.action("Executing: \(action)")
            let entry = await executeSingle(action)
            actionHistory.append(entry)
            lastExecutedAction = entry.action

            if !entry.success {
                Log.error("Action failed: \(entry.detail)")
            }
        }

        isExecuting = false
    }

    /// Execute a single action
    private func executeSingle(_ action: AIAction) async -> ActionLogEntry {
        let timestamp = Date()

        switch action {
        case .click(let x, let y):
            let point = CGPoint(x: x, y: y)
            inputControl.click(at: point)
            Log.action("  -> Clicked at (\(x), \(y))")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Clicked at (\(x), \(y))")

        case .rightClick(let x, let y):
            let point = CGPoint(x: x, y: y)
            inputControl.rightClick(at: point)
            Log.action("  -> Right-clicked at (\(x), \(y))")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Right-clicked at (\(x), \(y))")

        case .doubleClick(let x, let y):
            let point = CGPoint(x: x, y: y)
            inputControl.doubleClick(at: point)
            Log.action("  -> Double-clicked at (\(x), \(y))")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Double-clicked at (\(x), \(y))")

        case .moveMouse(let x, let y):
            let point = CGPoint(x: x, y: y)
            inputControl.moveMouse(to: point)
            Log.action("  -> Moved mouse to (\(x), \(y))")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Moved to (\(x), \(y))")

        case .typeText(let text):
            inputControl.typeText(text)
            Log.action("  -> Typed: \"\(text.prefix(50))\"")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Typed \(text.count) chars")

        case .pressKey(let key, let modifiers):
            if let keyCode = resolveKeyCode(key) {
                let flags = resolveModifiers(modifiers)
                inputControl.pressKey(keyCode, modifiers: flags)
                Log.action("  -> Pressed key: \(key) (modifiers: \(modifiers))")
                return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Pressed \(key)")
            } else {
                Log.error("  -> Unknown key: \(key)")
                return ActionLogEntry(timestamp: timestamp, action: action.description, success: false, detail: "Unknown key: \(key)")
            }

        case .scroll(let dx, let dy):
            inputControl.scroll(deltaX: Int32(dx), deltaY: Int32(dy))
            Log.action("  -> Scrolled (dx:\(dx), dy:\(dy))")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Scrolled")

        case .drag(let fx, let fy, let tx, let ty):
            let from = CGPoint(x: fx, y: fy)
            let to = CGPoint(x: tx, y: ty)
            inputControl.drag(from: from, to: to)
            Log.action("  -> Dragged from (\(fx),\(fy)) to (\(tx),\(ty))")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Dragged")

        case .wait(let seconds):
            Log.action("  -> Waiting \(seconds)s...")
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Waited \(seconds)s")

        case .screenshot:
            Log.action("  -> Screenshot requested (handled by caller)")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Screenshot requested")

        case .openApp(let name):
            inputControl.openApplication(name)
            Log.action("  -> Opening app: \(name)")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Opened \(name)")

        case .thinking(let thought):
            Log.info("  AI thinking: \(thought.prefix(100))")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: thought)
        }
    }

    // MARK: - Key Resolution

    private func resolveKeyCode(_ key: String) -> InputControlService.Key? {
        switch key.lowercased() {
        case "return", "enter": return .returnKey
        case "tab": return .tab
        case "space": return .space
        case "delete", "backspace": return .delete
        case "escape", "esc": return .escape
        case "up", "arrow_up": return .arrowUp
        case "down", "arrow_down": return .arrowDown
        case "left", "arrow_left": return .arrowLeft
        case "right", "arrow_right": return .arrowRight
        case "a": return .a
        case "b": return .b
        case "c": return .c
        case "d": return .d
        case "e": return .e
        case "f": return .f
        case "g": return .g
        case "h": return .h
        case "i": return .i
        case "j": return .j
        case "k": return .k
        case "l": return .l
        case "m": return .m
        case "n": return .n
        case "o": return .o
        case "p": return .p
        case "q": return .q
        case "r": return .r
        case "s": return .s
        case "t": return .t
        case "u": return .u
        case "v": return .v
        case "w": return .w
        case "x": return .x
        case "y": return .y
        case "z": return .z
        default: return nil
        }
    }

    private func resolveModifiers(_ modifiers: [String]) -> CGEventFlags {
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod.lowercased() {
            case "command", "cmd": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "option", "alt": flags.insert(.maskAlternate)
            case "control", "ctrl": flags.insert(.maskControl)
            default: break
            }
        }
        return flags
    }
}

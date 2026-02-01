import Foundation
import CoreGraphics

struct CoordinateContext {
    let displayWidth: Int   // macOS points
    let displayHeight: Int  // macOS points
    let imageWidth: Int     // resized image px
    let imageHeight: Int    // resized image px
    // Letterbox offset (for tile-aligned mode)
    let letterboxOffsetX: Int   // default 0
    let letterboxOffsetY: Int   // default 0
    let letterboxImageW: Int    // actual image w inside canvas (default = imageWidth)
    let letterboxImageH: Int    // actual image h inside canvas (default = imageHeight)

    init(displayWidth: Int, displayHeight: Int, imageWidth: Int, imageHeight: Int,
         letterboxOffsetX: Int = 0, letterboxOffsetY: Int = 0,
         letterboxImageW: Int? = nil, letterboxImageH: Int? = nil) {
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.letterboxOffsetX = letterboxOffsetX
        self.letterboxOffsetY = letterboxOffsetY
        self.letterboxImageW = letterboxImageW ?? imageWidth
        self.letterboxImageH = letterboxImageH ?? imageHeight
    }
}

/// Executes AI-parsed actions using InputControlService.
/// Provides logging to terminal for debugging.
@MainActor
final class ActionExecutor: ObservableObject {
    @Published var lastExecutedAction: String = ""
    @Published var actionHistory: [ActionLogEntry] = []
    @Published var isExecuting = false

    /// Tracks net show_desktop calls in current execution batch (odd = desktop revealed)
    private var showDesktopCount = 0

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

    /// Execute a list of actions sequentially (no coordinate mapping)
    func execute(actions: [AIAction]) async {
        await execute(actions: actions, coordinateContext: nil)
    }

    /// Execute a list of actions sequentially, optionally mapping AI image coordinates to display points
    func execute(actions: [AIAction], coordinateContext: CoordinateContext?) async {
        guard !actions.isEmpty else { return }
        isExecuting = true
        showDesktopCount = 0

        if let ctx = coordinateContext {
            Log.info("Coordinate mapping: image(\(ctx.imageWidth)x\(ctx.imageHeight)) -> display(\(ctx.displayWidth)x\(ctx.displayHeight))")
        }

        for action in actions {
            let mapped = coordinateContext.map { mapAction(action, context: $0) } ?? action
            Log.action("Executing: \(mapped)")
            let entry = await executeSingle(mapped)
            actionHistory.append(entry)
            lastExecutedAction = entry.action

            if !entry.success {
                Log.error("Action failed: \(entry.detail)")
            }
        }

        // Auto-restore desktop if show_desktop was called an odd number of times
        // (meaning desktop is still revealed when actions finished)
        if showDesktopCount % 2 == 1 {
            Log.info("Auto-restoring desktop (show_desktop called \(showDesktopCount) time(s) — desktop still revealed)")
            // Brief delay to let the last action settle before restoring
            try? await Task.sleep(nanoseconds: 500_000_000)
            inputControl.showDesktop()
            showDesktopCount += 1
            let entry = ActionLogEntry(timestamp: Date(), action: "SHOW_DESKTOP (auto-restore)", success: true, detail: "Desktop auto-restored after action execution")
            actionHistory.append(entry)
        }

        isExecuting = false
    }

    // MARK: - Tile Grid (3x2 on 1344x896)

    private static let tileOffsets: [String: (x: Int, y: Int)] = [
        "A1": (0, 0),     "A2": (448, 0),   "A3": (896, 0),
        "B1": (0, 448),   "B2": (448, 448),  "B3": (896, 448),
    ]

    private func tileToGlobal(tile: String, localX: Int, localY: Int) -> (Int, Int) {
        guard let offset = Self.tileOffsets[tile.uppercased()] else {
            Log.error("Unknown tile ID: \(tile)")
            return (localX, localY)
        }
        let globalX = offset.x + min(max(localX, 0), 447)
        let globalY = offset.y + min(max(localY, 0), 447)
        Log.info("Tile \(tile) local (\(localX), \(localY)) -> global (\(globalX), \(globalY))")
        return (globalX, globalY)
    }

    /// Map a list of actions through a coordinate context (for pre-execution refinement)
    func mapActions(_ actions: [AIAction], coordinateContext: CoordinateContext?) -> [AIAction] {
        guard let ctx = coordinateContext else { return actions }
        return actions.map { mapAction($0, context: ctx) }
    }

    // MARK: - Coordinate Mapping

    private func scalePoint(x: Int, y: Int, context: CoordinateContext) -> (Int, Int) {
        let clampedX = min(max(x, 0), context.imageWidth - 1)
        let clampedY = min(max(y, 0), context.imageHeight - 1)

        if clampedX != x || clampedY != y {
            Log.info("Clamped AI coordinate (\(x), \(y)) -> (\(clampedX), \(clampedY)) [image bounds: \(context.imageWidth)x\(context.imageHeight)]")
        }

        // Subtract letterbox offset before scaling (for tile-aligned mode)
        let adjustedX = clampedX - context.letterboxOffsetX
        let adjustedY = clampedY - context.letterboxOffsetY

        let screenX = max(0, min(adjustedX * context.displayWidth / context.letterboxImageW, context.displayWidth - 1))
        let screenY = max(0, min(adjustedY * context.displayHeight / context.letterboxImageH, context.displayHeight - 1))

        // Sanity check: warn if mapped point is in a different quadrant than the AI coordinate
        let aiQuadX = clampedX < context.imageWidth / 2  // AI intended left half
        let aiQuadY = clampedY < context.imageHeight / 2 // AI intended top half
        let screenQuadX = screenX < context.displayWidth / 2
        let screenQuadY = screenY < context.displayHeight / 2
        if aiQuadX != screenQuadX || aiQuadY != screenQuadY {
            Log.error("QUADRANT MISMATCH: AI coord (\(x),\(y)) maps to screen (\(screenX),\(screenY)) — different quadrant! Possible coordinate inversion.")
        }

        Log.info("Mapped (\(x), \(y)) [image] -> (\(screenX), \(screenY)) [display points] (letterbox offset: \(context.letterboxOffsetX),\(context.letterboxOffsetY))")
        return (screenX, screenY)
    }

    private func mapAction(_ action: AIAction, context: CoordinateContext) -> AIAction {
        switch action {
        case .click(let x, let y):
            let (sx, sy) = scalePoint(x: x, y: y, context: context)
            return .click(x: sx, y: sy)
        case .rightClick(let x, let y):
            let (sx, sy) = scalePoint(x: x, y: y, context: context)
            return .rightClick(x: sx, y: sy)
        case .doubleClick(let x, let y):
            let (sx, sy) = scalePoint(x: x, y: y, context: context)
            return .doubleClick(x: sx, y: sy)
        case .moveMouse(let x, let y):
            let (sx, sy) = scalePoint(x: x, y: y, context: context)
            return .moveMouse(x: sx, y: sy)
        case .drag(let fx, let fy, let tx, let ty):
            let (sfx, sfy) = scalePoint(x: fx, y: fy, context: context)
            let (stx, sty) = scalePoint(x: tx, y: ty, context: context)
            return .drag(fromX: sfx, fromY: sfy, toX: stx, toY: sty)
        case .clickRegion(let x1, let y1, let x2, let y2):
            let (sx1, sy1) = scalePoint(x: x1, y: y1, context: context)
            let (sx2, sy2) = scalePoint(x: x2, y: y2, context: context)
            return .clickRegion(x1: sx1, y1: sy1, x2: sx2, y2: sy2)
        case .clickTile(let tile, let localX, let localY):
            let (gx, gy) = tileToGlobal(tile: tile, localX: localX, localY: localY)
            let (sx, sy) = scalePoint(x: gx, y: gy, context: context)
            return .click(x: sx, y: sy)
        case .clickElement:
            return action
        case .showDesktop:
            return action
        default:
            return action
        }
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

        case .showDesktop:
            inputControl.showDesktop()
            showDesktopCount += 1
            Log.action("  -> Toggled Show Desktop")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Show Desktop toggled")

        case .openApp(let name):
            inputControl.openApplication(name)
            Log.action("  -> Opening app: \(name)")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true, detail: "Opened \(name)")

        case .focusApp(let name):
            let success = inputControl.focusApplication(name)
            if success {
                Log.action("  -> Focused app: \(name)")
            } else {
                Log.error("  -> Failed to focus app: \(name)")
            }
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: success, detail: success ? "Focused \(name)" : "Failed to focus \(name)")

        case .clickRegion(let x1, let y1, let x2, let y2):
            let cx = (x1 + x2) / 2
            let cy = (y1 + y2) / 2
            inputControl.click(at: CGPoint(x: cx, y: cy))
            Log.action("  -> Click-region centroid at (\(cx), \(cy)) [box: (\(x1),\(y1))->(\(x2),\(y2))]")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true,
                                  detail: "Click-region centroid at (\(cx), \(cy))")

        case .clickElement(let name):
            let result = inputControl.findAndClickElement(named: name)
            if result.success {
                Log.action("  -> Smart-clicked: \(result.detail)")
            } else {
                Log.error("  -> Smart-click failed: \(result.detail)")
            }
            return ActionLogEntry(timestamp: timestamp, action: action.description,
                                  success: result.success, detail: result.detail)

        case .clickTile(let tile, let localX, let localY):
            let (gx, gy) = tileToGlobal(tile: tile, localX: localX, localY: localY)
            let point = CGPoint(x: gx, y: gy)
            inputControl.click(at: point)
            Log.action("  -> Tile-click \(tile) local (\(localX),\(localY)) -> global (\(gx), \(gy))")
            return ActionLogEntry(timestamp: timestamp, action: action.description, success: true,
                                  detail: "Tile \(tile) clicked at (\(gx), \(gy))")

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
        case "[", "leftbracket", "left_bracket": return .leftBracket
        case "]", "rightbracket", "right_bracket": return .rightBracket
        case ",", "comma": return .comma
        case ".", "period": return .period
        case "/", "slash": return .slash
        case "-", "minus", "hyphen": return .minus
        case "=", "equal", "equals", "plus": return .equal
        case ";", "semicolon": return .semicolon
        case "\\", "backslash": return .backslash
        case "`", "grave", "backtick": return .grave
        case "f1": return .f1
        case "f2": return .f2
        case "f3": return .f3
        case "f4": return .f4
        case "f5": return .f5
        case "f6": return .f6
        case "f7": return .f7
        case "f8": return .f8
        case "f9": return .f9
        case "f10": return .f10
        case "f11": return .f11
        case "f12": return .f12
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
            case "fn", "function": flags.insert(CGEventFlags(rawValue: 0x800000))
            default: break
            }
        }
        return flags
    }
}

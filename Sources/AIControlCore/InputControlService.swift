import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

public struct SmartClickResult {
    public let success: Bool
    public let detail: String
    public let clickedPoint: CGPoint?

    public init(success: Bool, detail: String, clickedPoint: CGPoint?) {
        self.success = success
        self.detail = detail
        self.clickedPoint = clickedPoint
    }
}

public struct CalibrationLandmark {
    public let name: String
    public let expectedDisplayPoint: CGPoint

    public init(name: String, expectedDisplayPoint: CGPoint) {
        self.name = name
        self.expectedDisplayPoint = expectedDisplayPoint
    }
}

public struct CalibrationPoint {
    public let label: String
    public let target: CGPoint
    public let actual: CGPoint
    public let errorPixels: Double

    public init(label: String, target: CGPoint, actual: CGPoint, errorPixels: Double) {
        self.label = label
        self.target = target
        self.actual = actual
        self.errorPixels = errorPixels
    }
}

public struct InputCalibrationResult {
    public let points: [CalibrationPoint]
    public let averageError: Double
    public let maxError: Double
    public let passed: Bool  // average error < 5px

    public init(points: [CalibrationPoint], averageError: Double, maxError: Double, passed: Bool) {
        self.points = points
        self.averageError = averageError
        self.maxError = maxError
        self.passed = passed
    }
}

@MainActor
public final class InputControlService: ObservableObject {
    @Published public var isEnabled = false
    @Published public var hasAccessibilityPermission = false
    @Published public var lastAction: String = ""

    public enum Key: UInt16 {
        case returnKey = 36, tab = 48, space = 49, delete = 51
        case escape = 53, command = 55, shift = 56, option = 58
        case control = 59, arrowLeft = 123, arrowRight = 124
        case arrowDown = 125, arrowUp = 126
        case a = 0, s = 1, d = 2, f = 3, g = 5, h = 4
        case j = 38, k = 40, l = 37, z = 6, x = 7, c = 8
        case v = 9, b = 11, q = 12, w = 13, e = 14, r = 15
        case t = 17, y = 16, u = 32, i = 34, o = 31, p = 35
        case n = 45, m = 46
        // Punctuation / symbols
        case leftBracket = 33, rightBracket = 30
        case comma = 43, period = 47, slash = 44
        case minus = 27, equal = 24, semicolon = 41
        case backslash = 42, grave = 50  // ` key
        // Function keys
        case f1 = 122, f2 = 120, f3 = 99, f4 = 118
        case f5 = 96, f6 = 97, f7 = 98, f8 = 100
        case f9 = 101, f10 = 109, f11 = 103, f12 = 111
    }

    public init() {}

    public func checkPermissions() -> Bool {
        let trusted = AXIsProcessTrusted()
        hasAccessibilityPermission = trusted
        return trusted
    }

    public func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    public func moveMouse(to point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
        lastAction = "Mouse moved to (\(Int(point.x)), \(Int(point.y)))"
    }

    public func click(at point: CGPoint? = nil) {
        let location = point ?? CGEvent(source: nil)?.location ?? .zero

        if let point = point {
            moveMouse(to: point)
            usleep(10000)
        }

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                               mouseCursorPosition: location, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                             mouseCursorPosition: location, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
        lastAction = "Clicked at (\(Int(location.x)), \(Int(location.y)))"
    }

    public func rightClick(at point: CGPoint? = nil) {
        let location = point ?? CGEvent(source: nil)?.location ?? .zero

        if let point = point {
            moveMouse(to: point)
            usleep(10000)
        }

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown,
                               mouseCursorPosition: location, mouseButton: .right)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
                             mouseCursorPosition: location, mouseButton: .right)
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
        lastAction = "Right-clicked at (\(Int(location.x)), \(Int(location.y)))"
    }

    public func doubleClick(at point: CGPoint? = nil) {
        let location = point ?? CGEvent(source: nil)?.location ?? .zero

        if let point = point {
            moveMouse(to: point)
            usleep(10000)
        }

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                               mouseCursorPosition: location, mouseButton: .left)
        mouseDown?.setIntegerValueField(.mouseEventClickState, value: 2)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                             mouseCursorPosition: location, mouseButton: .left)
        mouseUp?.setIntegerValueField(.mouseEventClickState, value: 2)
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
        lastAction = "Double-clicked at (\(Int(location.x)), \(Int(location.y)))"
    }

    public func typeText(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for char in text {
            let str = String(char)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            var unichar = [UniChar](str.utf16)
            keyDown?.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)
            keyUp?.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)
            keyDown?.post(tap: .cghidEventTap)
            usleep(10_000) // 10ms between keyDown and keyUp
            keyUp?.post(tap: .cghidEventTap)
            usleep(20_000) // 20ms between characters
        }
        lastAction = "Typed: \(text.prefix(50))\(text.count > 50 ? "..." : "")"
    }

    public func pressKey(_ key: Key, modifiers: CGEventFlags = []) {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Send modifier key-down events separately (required for system shortcuts like Cmd+F3)
        let modifierKeys = modifierVirtualKeys(for: modifiers)
        for modKey in modifierKeys {
            let modDown = CGEvent(keyboardEventSource: source, virtualKey: modKey, keyDown: true)
            modDown?.flags = modifiers
            modDown?.post(tap: .cghidEventTap)
        }
        if !modifierKeys.isEmpty {
            usleep(30_000) // 30ms for modifiers to register
        }

        // Send the actual key press with modifier flags
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: false)
        if !modifiers.isEmpty {
            keyDown?.flags = modifiers
            keyUp?.flags = modifiers
        }
        keyDown?.post(tap: .cghidEventTap)
        usleep(50_000) // 50ms between keyDown and keyUp for reliable registration
        keyUp?.post(tap: .cghidEventTap)

        // Release modifier keys
        if !modifierKeys.isEmpty {
            usleep(30_000)
        }
        for modKey in modifierKeys {
            let modUp = CGEvent(keyboardEventSource: source, virtualKey: modKey, keyDown: false)
            modUp?.post(tap: .cghidEventTap)
        }

        lastAction = "Pressed key: \(key)"
    }

    /// Toggle Show Desktop - hides all windows to reveal the desktop, or restores them.
    public func showDesktop() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let fnFlag = CGEventFlags(rawValue: 0x800000) // maskSecondaryFn

        // Approach: Send Fn+F11 (standard Show Desktop shortcut)
        let f11Down = CGEvent(keyboardEventSource: source, virtualKey: 103, keyDown: true)
        let f11Up = CGEvent(keyboardEventSource: source, virtualKey: 103, keyDown: false)
        f11Down?.flags = fnFlag
        f11Up?.flags = fnFlag
        f11Down?.post(tap: .cghidEventTap)
        usleep(50_000)
        f11Up?.post(tap: .cghidEventTap)

        lastAction = "Show Desktop toggled"
    }

    /// Map CGEventFlags to the virtual key codes for the modifier keys themselves
    private func modifierVirtualKeys(for flags: CGEventFlags) -> [UInt16] {
        var keys: [UInt16] = []
        if flags.contains(.maskCommand) { keys.append(55) }   // Left Command
        if flags.contains(.maskShift)   { keys.append(56) }   // Left Shift
        if flags.contains(.maskAlternate) { keys.append(58) }  // Left Option
        if flags.contains(.maskControl) { keys.append(59) }   // Left Control
        return keys
    }

    /// Open an application by name using NSWorkspace (reliable, no Spotlight needed)
    public func openApplication(_ name: String) {
        // Try NSWorkspace URL lookup first
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID(for: name)) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    Log.error("NSWorkspace failed to open \(name): \(error.localizedDescription)")
                }
            }
            lastAction = "Opened app: \(name) (via bundle ID)"
            return
        }

        // Fallback: use shell `open -a` command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", name]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                lastAction = "Opened app: \(name) (via open -a)"
            } else {
                Log.error("open -a \(name) exited with status \(task.terminationStatus)")
                lastAction = "Failed to open: \(name)"
            }
        } catch {
            Log.error("Failed to run open -a \(name): \(error.localizedDescription)")
            lastAction = "Failed to open: \(name)"
        }
    }

    /// Bring a running application to the front without launching it
    @discardableResult
    public func focusApplication(_ name: String) -> Bool {
        // Try finding by bundle ID first
        let bid = bundleID(for: name)
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first {
            app.activate()
            lastAction = "Focused app: \(name)"
            Log.action("Focused \(name) via bundle ID (\(bid))")
            return true
        }

        // Fallback: search by localized name
        for app in NSWorkspace.shared.runningApplications {
            if let localName = app.localizedName, localName.lowercased() == name.lowercased() {
                app.activate()
                lastAction = "Focused app: \(name)"
                Log.action("Focused \(name) via localized name")
                return true
            }
        }

        Log.error("Cannot focus \(name): app not found running")
        lastAction = "Failed to focus: \(name)"
        return false
    }

    /// Map common app names to bundle identifiers
    private func bundleID(for appName: String) -> String {
        switch appName.lowercased() {
        case "safari": return "com.apple.Safari"
        case "finder": return "com.apple.finder"
        case "terminal": return "com.apple.Terminal"
        case "mail": return "com.apple.mail"
        case "messages": return "com.apple.MobileSMS"
        case "notes": return "com.apple.Notes"
        case "calendar": return "com.apple.iCal"
        case "music": return "com.apple.Music"
        case "photos": return "com.apple.Photos"
        case "maps": return "com.apple.Maps"
        case "preview": return "com.apple.Preview"
        case "textedit", "text edit": return "com.apple.TextEdit"
        case "system preferences", "system settings": return "com.apple.systempreferences"
        case "activity monitor": return "com.apple.ActivityMonitor"
        case "app store": return "com.apple.AppStore"
        case "chrome", "google chrome": return "com.google.Chrome"
        case "firefox": return "org.mozilla.firefox"
        case "slack": return "com.tinyspeck.slackmacgap"
        case "discord": return "com.hnc.Discord"
        case "spotify": return "com.spotify.client"
        case "vscode", "visual studio code": return "com.microsoft.VSCode"
        case "iterm", "iterm2": return "com.googlecode.iterm2"
        case "xcode": return "com.apple.dt.Xcode"
        default: return "com.apple.\(appName)"
        }
    }

    public func scroll(deltaX: Int32 = 0, deltaY: Int32) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                           wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0)
        event?.post(tap: .cghidEventTap)
        lastAction = "Scrolled (dx: \(deltaX), dy: \(deltaY))"
    }

    public func drag(from start: CGPoint, to end: CGPoint, duration: TimeInterval = 0.5) {
        let steps = Int(duration * 60)
        let dx = (end.x - start.x) / CGFloat(steps)
        let dy = (end.y - start.y) / CGFloat(steps)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                               mouseCursorPosition: start, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)

        // Hold stationary for 150ms after mouseDown so Finder (and similar apps)
        // register the press and "pick up" the item before movement begins.
        usleep(150_000)

        for i in 1...steps {
            let point = CGPoint(x: start.x + dx * CGFloat(i), y: start.y + dy * CGFloat(i))
            let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                              mouseCursorPosition: point, mouseButton: .left)
            drag?.post(tap: .cghidEventTap)
            usleep(UInt32(1_000_000 * duration / Double(steps)))
        }

        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                             mouseCursorPosition: end, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
        lastAction = "Dragged from (\(Int(start.x)),\(Int(start.y))) to (\(Int(end.x)),\(Int(end.y)))"
    }

    // MARK: - Calibration

    /// Run mechanical Tier-1 calibration: move mouse to known points and measure actual position.
    public func runCalibration(displayWidth: Int, displayHeight: Int) -> InputCalibrationResult {
        let w = CGFloat(displayWidth)
        let h = CGFloat(displayHeight)
        let margin: CGFloat = 50

        let targets: [(String, CGPoint)] = [
            ("Center", CGPoint(x: w / 2, y: h / 2)),
            ("Top-Left", CGPoint(x: margin, y: margin)),
            ("Top-Right", CGPoint(x: w - margin, y: margin)),
            ("Bottom-Left", CGPoint(x: margin, y: h - margin)),
            ("Bottom-Right", CGPoint(x: w - margin, y: h - margin)),
        ]

        var points: [CalibrationPoint] = []

        for (label, target) in targets {
            // Move mouse to target
            moveMouse(to: target)
            usleep(50_000) // 50ms settle time

            // Read back actual cursor position
            let actual = CGEvent(source: nil)?.location ?? .zero
            let dx = actual.x - target.x
            let dy = actual.y - target.y
            let error = sqrt(dx * dx + dy * dy)

            points.append(CalibrationPoint(
                label: label,
                target: target,
                actual: actual,
                errorPixels: error
            ))

            Log.info("Calibration '\(label)': target=(\(Int(target.x)),\(Int(target.y))) actual=(\(Int(actual.x)),\(Int(actual.y))) error=\(String(format: "%.1f", error))px")
        }

        let avgError = points.map(\.errorPixels).reduce(0, +) / Double(points.count)
        let maxError = points.map(\.errorPixels).max() ?? 0

        Log.info("Calibration complete: avg=\(String(format: "%.1f", avgError))px max=\(String(format: "%.1f", maxError))px passed=\(avgError < 5)")

        return InputCalibrationResult(
            points: points,
            averageError: avgError,
            maxError: maxError,
            passed: avgError < 5
        )
    }

    /// Get current cursor position
    public nonisolated static func getCursorPosition() -> CGPoint {
        return CGEvent(source: nil)?.location ?? .zero
    }

    // MARK: - Static CGEvent Methods (nonisolated, for CLI use)

    /// Post a click at coordinates - can be called from any thread
    public nonisolated static func postClick(at point: CGPoint) {
        let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                          mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        usleep(10000)

        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                          mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                        mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Post a right-click at coordinates - can be called from any thread
    public nonisolated static func postRightClick(at point: CGPoint) {
        let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                          mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        usleep(10000)

        let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown,
                          mouseCursorPosition: point, mouseButton: .right)
        let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
                        mouseCursorPosition: point, mouseButton: .right)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Post a double-click at coordinates - can be called from any thread
    public nonisolated static func postDoubleClick(at point: CGPoint) {
        let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                          mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        usleep(10000)

        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                          mouseCursorPosition: point, mouseButton: .left)
        down?.setIntegerValueField(.mouseEventClickState, value: 2)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                        mouseCursorPosition: point, mouseButton: .left)
        up?.setIntegerValueField(.mouseEventClickState, value: 2)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Post mouse move - can be called from any thread
    public nonisolated static func postMoveMouse(to point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }

    /// Post typed text - can be called from any thread
    public nonisolated static func postTypeText(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for char in text {
            let str = String(char)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            var unichar = [UniChar](str.utf16)
            keyDown?.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)
            keyUp?.keyboardSetUnicodeString(stringLength: unichar.count, unicodeString: &unichar)
            keyDown?.post(tap: .cghidEventTap)
            usleep(10_000)
            keyUp?.post(tap: .cghidEventTap)
            usleep(20_000)
        }
    }

    /// Post key press - can be called from any thread
    public nonisolated static func postKeyPress(_ key: Key, modifiers: CGEventFlags = []) {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Build modifier keys
        var modifierKeys: [UInt16] = []
        if modifiers.contains(.maskCommand) { modifierKeys.append(55) }
        if modifiers.contains(.maskShift) { modifierKeys.append(56) }
        if modifiers.contains(.maskAlternate) { modifierKeys.append(58) }
        if modifiers.contains(.maskControl) { modifierKeys.append(59) }

        // Press modifier keys
        for modKey in modifierKeys {
            let modDown = CGEvent(keyboardEventSource: source, virtualKey: modKey, keyDown: true)
            modDown?.flags = modifiers
            modDown?.post(tap: .cghidEventTap)
        }
        if !modifierKeys.isEmpty { usleep(30_000) }

        // Press main key
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: false)
        if !modifiers.isEmpty {
            keyDown?.flags = modifiers
            keyUp?.flags = modifiers
        }
        keyDown?.post(tap: .cghidEventTap)
        usleep(50_000)
        keyUp?.post(tap: .cghidEventTap)

        // Release modifier keys
        if !modifierKeys.isEmpty { usleep(30_000) }
        for modKey in modifierKeys {
            let modUp = CGEvent(keyboardEventSource: source, virtualKey: modKey, keyDown: false)
            modUp?.post(tap: .cghidEventTap)
        }
    }

    /// Post scroll - can be called from any thread
    public nonisolated static func postScroll(deltaX: Int32 = 0, deltaY: Int32) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                           wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }

    /// Post drag - can be called from any thread
    public nonisolated static func postDrag(from start: CGPoint, to end: CGPoint, duration: TimeInterval = 0.5) {
        let steps = Int(duration * 60)
        let dx = (end.x - start.x) / CGFloat(steps)
        let dy = (end.y - start.y) / CGFloat(steps)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                               mouseCursorPosition: start, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        usleep(150_000)

        for i in 1...steps {
            let point = CGPoint(x: start.x + dx * CGFloat(i), y: start.y + dy * CGFloat(i))
            let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                              mouseCursorPosition: point, mouseButton: .left)
            drag?.post(tap: .cghidEventTap)
            usleep(UInt32(1_000_000 * duration / Double(steps)))
        }

        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                             mouseCursorPosition: end, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
    }

    /// Open application by name - can be called from any thread
    public nonisolated static func postOpenApp(_ name: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", name]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Focus application by name - can be called from any thread
    public nonisolated static func postFocusApp(_ name: String) -> Bool {
        let script = """
        tell application "\(name)" to activate
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Show desktop (Fn+F11) - can be called from any thread
    public nonisolated static func postShowDesktop() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let fnFlag = CGEventFlags(rawValue: 0x800000) // maskSecondaryFn
        let f11Down = CGEvent(keyboardEventSource: source, virtualKey: 103, keyDown: true)
        let f11Up = CGEvent(keyboardEventSource: source, virtualKey: 103, keyDown: false)
        f11Down?.flags = fnFlag
        f11Up?.flags = fnFlag
        f11Down?.post(tap: .cghidEventTap)
        usleep(50_000)
        f11Up?.post(tap: .cghidEventTap)
    }

    /// Get display dimensions
    public nonisolated static func getDisplayDimensions() -> (width: Int, height: Int, scaleFactor: Double) {
        guard let mainScreen = NSScreen.main else {
            return (0, 0, 1.0)
        }
        let frame = mainScreen.frame
        let scaleFactor = mainScreen.backingScaleFactor
        return (Int(frame.width), Int(frame.height), scaleFactor)
    }

    /// Check if screen recording permission is granted
    public nonisolated static func hasScreenRecordingPermission() -> Bool {
        // Attempt to get shareable content - this will fail if permission is not granted
        let semaphore = DispatchSemaphore(value: 0)
        var hasPermission = false

        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                hasPermission = true
            } catch {
                hasPermission = false
            }
            semaphore.signal()
        }

        semaphore.wait()
        return hasPermission
    }

    /// Resolve key name string to Key enum
    public nonisolated static func resolveKeyCode(_ key: String) -> Key? {
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

    /// Resolve modifier string array to CGEventFlags
    public nonisolated static func resolveModifiers(_ modifiers: [String]) -> CGEventFlags {
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

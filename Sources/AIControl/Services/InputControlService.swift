import Foundation
import CoreGraphics
import AppKit

@MainActor
final class InputControlService: ObservableObject {
    @Published var isEnabled = false
    @Published var hasAccessibilityPermission = false
    @Published var lastAction: String = ""

    enum Key: UInt16 {
        case returnKey = 36, tab = 48, space = 49, delete = 51
        case escape = 53, command = 55, shift = 56, option = 58
        case control = 59, arrowLeft = 123, arrowRight = 124
        case arrowDown = 125, arrowUp = 126
        case a = 0, s = 1, d = 2, f = 3, g = 5, h = 4
        case j = 38, k = 40, l = 37, z = 6, x = 7, c = 8
        case v = 9, b = 11, q = 12, w = 13, e = 14, r = 15
        case t = 17, y = 16, u = 32, i = 34, o = 31, p = 35
        case n = 45, m = 46
    }

    func checkPermissions() -> Bool {
        let trusted = AXIsProcessTrusted()
        hasAccessibilityPermission = trusted
        return trusted
    }

    func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func moveMouse(to point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
        lastAction = "Mouse moved to (\(Int(point.x)), \(Int(point.y)))"
    }

    func click(at point: CGPoint? = nil) {
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

    func rightClick(at point: CGPoint? = nil) {
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

    func doubleClick(at point: CGPoint? = nil) {
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

    func typeText(_ text: String) {
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

    func pressKey(_ key: Key, modifiers: CGEventFlags = []) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: false)
        if !modifiers.isEmpty {
            keyDown?.flags = modifiers
            keyUp?.flags = modifiers
        }
        keyDown?.post(tap: .cghidEventTap)
        usleep(50_000) // 50ms between keyDown and keyUp for reliable registration
        keyUp?.post(tap: .cghidEventTap)
        lastAction = "Pressed key: \(key)"
    }

    /// Open an application by name using NSWorkspace (reliable, no Spotlight needed)
    func openApplication(_ name: String) {
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

    func scroll(deltaX: Int32 = 0, deltaY: Int32) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                           wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0)
        event?.post(tap: .cghidEventTap)
        lastAction = "Scrolled (dx: \(deltaX), dy: \(deltaY))"
    }

    func drag(from start: CGPoint, to end: CGPoint, duration: TimeInterval = 0.5) {
        let steps = Int(duration * 60)
        let dx = (end.x - start.x) / CGFloat(steps)
        let dy = (end.y - start.y) / CGFloat(steps)

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                               mouseCursorPosition: start, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)

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
}

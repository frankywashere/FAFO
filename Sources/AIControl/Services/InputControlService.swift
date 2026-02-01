import Foundation
import CoreGraphics
import AppKit

struct SmartClickResult {
    let success: Bool
    let detail: String
    let clickedPoint: CGPoint?
}

struct CalibrationLandmark {
    let name: String
    let expectedDisplayPoint: CGPoint
}

struct CalibrationPoint {
    let label: String
    let target: CGPoint
    let actual: CGPoint
    let errorPixels: Double
}

struct CalibrationResult {
    let points: [CalibrationPoint]
    let averageError: Double
    let maxError: Double
    let passed: Bool  // average error < 5px
}

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

    /// Toggle Show Desktop — hides all windows to reveal the desktop, or restores them.
    /// Uses multiple approaches for reliability across different macOS configurations.
    func showDesktop() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let fnFlag = CGEventFlags(rawValue: 0x800000) // maskSecondaryFn

        // Approach: Send Fn+F11 (standard Show Desktop shortcut)
        // F11 = keycode 103, with Fn modifier to ensure it acts as a function key
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

    /// Bring a running application to the front without launching it
    @discardableResult
    func focusApplication(_ name: String) -> Bool {
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

    // MARK: - Smart Click (Accessibility)

    func findAndClickElement(named name: String) -> SmartClickResult {
        // 1. Search frontmost app first (current behavior)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
            if let found = searchElementTree(root: appElement, name: name, maxDepth: 12, currentDepth: 0) {
                return clickFoundElement(found, name: name, source: frontApp.localizedName ?? "frontmost")
            }
        }

        // 2. Search Finder (for desktop file icons, Finder windows behind other apps)
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
           finder.processIdentifier != NSWorkspace.shared.frontmostApplication?.processIdentifier {
            let finderElement = AXUIElementCreateApplication(finder.processIdentifier)
            if let found = searchElementTree(root: finderElement, name: name, maxDepth: 12, currentDepth: 0) {
                return clickFoundElement(found, name: name, source: "Finder")
            }
        }

        // 3. Search system-wide (menu bar extras, system dialogs)
        let systemWide = AXUIElementCreateSystemWide()
        if let found = searchElementTree(root: systemWide, name: name, maxDepth: 6, currentDepth: 0) {
            return clickFoundElement(found, name: name, source: "system-wide")
        }

        return SmartClickResult(success: false, detail: "Element '\(name)' not found in any app", clickedPoint: nil)
    }

    private func clickFoundElement(_ element: AXUIElement, name: String, source: String) -> SmartClickResult {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return SmartClickResult(success: false, detail: "Element '\(name)' found in \(source) but has no position/size", clickedPoint: nil)
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return SmartClickResult(success: false, detail: "Element '\(name)' found in \(source) but could not read geometry", clickedPoint: nil)
        }

        let center = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)

        // Validate position is on-screen and element has real size
        let screenHeight = NSScreen.main?.frame.size.height ?? 1200

        if size.width < 1 || size.height < 1 {
            let msg = "Smart-click: rejecting '\(name)' in \(source) — zero-size element (\(size.width)x\(size.height))"
            Log.info(msg)
            return SmartClickResult(success: false, detail: msg, clickedPoint: nil)
        }
        if center.y < -50 {
            let msg = "Smart-click: rejecting '\(name)' in \(source) — way above screen at y=\(Int(center.y))"
            Log.info(msg)
            return SmartClickResult(success: false, detail: msg, clickedPoint: nil)
        }
        if center.y > screenHeight {
            let msg = "Smart-click: rejecting '\(name)' in \(source) — below screen bottom at y=\(Int(center.y)) (screen height=\(Int(screenHeight)))"
            Log.info(msg)
            return SmartClickResult(success: false, detail: msg, clickedPoint: nil)
        }
        if center.x < 2 && center.y > screenHeight / 2 {
            let msg = "Smart-click: rejecting '\(name)' in \(source) — left-edge hidden element at (\(Int(center.x)), \(Int(center.y)))"
            Log.info(msg)
            return SmartClickResult(success: false, detail: msg, clickedPoint: nil)
        }

        click(at: center)

        let detail = "Smart-clicked '\(name)' at (\(Int(center.x)), \(Int(center.y))) in \(source)"
        lastAction = detail
        return SmartClickResult(success: true, detail: detail, clickedPoint: center)
    }

    private func searchElementTree(root: AXUIElement, name: String, maxDepth: Int, currentDepth: Int) -> AXUIElement? {
        guard currentDepth < maxDepth else { return nil }

        let lowerName = name.lowercased()

        // Check attributes of current element
        let attributeKeys: [String] = [
            kAXTitleAttribute,
            kAXDescriptionAttribute,
            kAXValueAttribute,
            kAXIdentifierAttribute
        ]

        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1200)

        for key in attributeKeys {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(root, key as CFString, &value) == .success,
               let str = value as? String,
               str.lowercased().contains(lowerName) {
                // Only match elements that have a valid on-screen position
                var posValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(root, kAXPositionAttribute as CFString, &posValue) == .success {
                    var pos = CGPoint.zero
                    if AXValueGetValue(posValue as! AXValue, .cgPoint, &pos) {
                        // Reject bogus positions: way above screen, below bottom edge, or left-edge hidden
                        if pos.y < -50 || pos.y > screenSize.height || (pos.x < 2 && pos.y > screenSize.height / 2) {
                            Log.info("Smart-click: skipping '\(str)' at bogus position (\(Int(pos.x)), \(Int(pos.y)))")
                            // Don't return — let search continue to children
                        } else {
                            return root
                        }
                    }
                }
            }
        }

        // Recurse into children
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }

        for child in children {
            if let found = searchElementTree(root: child, name: name, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                return found
            }
        }

        return nil
    }

    // MARK: - Calibration

    /// Run mechanical Tier-1 calibration: move mouse to known points and measure actual position.
    /// displayWidth and displayHeight should be in macOS display points.
    func runCalibration(displayWidth: Int, displayHeight: Int) -> CalibrationResult {
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

        return CalibrationResult(
            points: points,
            averageError: avgError,
            maxError: maxError,
            passed: avgError < 5
        )
    }

    /// Return known landmark positions for AI calibration (Tier 2).
    /// Uses Accessibility APIs to find actual positions of menu bar items.
    func getCalibrationLandmarks(displayWidth: Int, displayHeight: Int) -> [CalibrationLandmark] {
        var landmarks: [CalibrationLandmark] = []

        // Apple menu is reliably at a fixed position
        landmarks.append(CalibrationLandmark(name: "Apple menu icon", expectedDisplayPoint: CGPoint(x: 18, y: 14)))

        // Try to find actual menu bar item positions via Accessibility
        // Search for menu bar items in the system-wide element tree
        // Fall back to heuristic positions if accessibility lookup fails
        if let menuBar = findMenuBar() {
            // Look for known items
            if let clockPos = findMenuBarItemPosition(menuBar: menuBar, name: "Clock") {
                landmarks.append(CalibrationLandmark(name: "Menu bar clock", expectedDisplayPoint: clockPos))
            } else {
                // Heuristic: on notch Macs the clock is right-of-center, on non-notch it's more centered
                let clockX = CGFloat(displayWidth) * 0.55
                landmarks.append(CalibrationLandmark(name: "Menu bar clock", expectedDisplayPoint: CGPoint(x: clockX, y: 14)))
            }

            if let spotlightPos = findMenuBarItemPosition(menuBar: menuBar, name: "Spotlight") {
                landmarks.append(CalibrationLandmark(name: "Spotlight search icon", expectedDisplayPoint: spotlightPos))
            }
        } else {
            // Fallback heuristics
            landmarks.append(CalibrationLandmark(name: "Menu bar clock", expectedDisplayPoint: CGPoint(x: CGFloat(displayWidth) * 0.55, y: 14)))
        }

        // Always add a reliable corner landmark: bottom-left corner of screen (Dock area)
        landmarks.append(CalibrationLandmark(name: "Bottom-left corner of screen", expectedDisplayPoint: CGPoint(x: 5, y: CGFloat(displayHeight) - 5)))

        return landmarks
    }

    private func findMenuBar() -> AXUIElement? {
        // Get the menu bar from the system (owned by the "SystemUIServer" process)
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier == "com.apple.systemuiserver" || app.bundleIdentifier == "com.apple.controlcenter" {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)
                var menuBarValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarValue) == .success {
                    return (menuBarValue as! AXUIElement)
                }
                // Try children for menu bar extras
                var childrenValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                   let children = childrenValue as? [AXUIElement] {
                    for child in children {
                        var roleValue: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue) == .success,
                           let role = roleValue as? String,
                           role == "AXMenuBar" || role == "AXMenuBarItem" {
                            return child
                        }
                    }
                }
            }
        }
        return nil
    }

    private func findMenuBarItemPosition(menuBar: AXUIElement, name: String) -> CGPoint? {
        let lowerName = name.lowercased()
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return nil }

        for child in children {
            // Check title/description
            for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, key as CFString, &value) == .success,
                   let str = value as? String,
                   str.lowercased().contains(lowerName) {
                    // Get position and size
                    var posValue: CFTypeRef?
                    var sizeValue: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &posValue) == .success,
                       AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeValue) == .success {
                        var pos = CGPoint.zero
                        var size = CGSize.zero
                        if AXValueGetValue(posValue as! AXValue, .cgPoint, &pos),
                           AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                            return CGPoint(x: pos.x + size.width / 2, y: pos.y + size.height / 2)
                        }
                    }
                }
            }
            // Recurse into child
            if let found = findMenuBarItemPosition(menuBar: child, name: name) {
                return found
            }
        }
        return nil
    }
}

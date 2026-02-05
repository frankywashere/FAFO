import ArgumentParser
import Foundation
import AIControlCore
import CoreGraphics

struct KeyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "key",
        abstract: "Press a key or key combination"
    )

    @Argument(help: "Key to press (e.g., 'enter', 'tab', 'escape', 'a', 'f1')")
    var key: String

    @Flag(name: .long, help: "Hold Command key")
    var command: Bool = false

    @Flag(name: .long, help: "Hold Control key")
    var control: Bool = false

    @Flag(name: .long, help: "Hold Option/Alt key")
    var option: Bool = false

    @Flag(name: .long, help: "Hold Shift key")
    var shift: Bool = false

    @Flag(name: .long, help: "Hold Function (Fn) key")
    var fn: Bool = false

    mutating func run() throws {
        // Resolve the key name to a Key enum
        guard let resolvedKey = InputControlService.resolveKeyCode(key) else {
            let result = CommandResult.failure(
                action: "key",
                error: "Unknown key: '\(key)'. Supported keys: a-z, f1-f12, enter, tab, escape, space, delete, up, down, left, right, comma, period, slash, minus, equal, semicolon, backslash, grave, leftbracket, rightbracket"
            )
            print(result.toJSON())
            return
        }

        // Build modifier flags
        var modifiers: [String] = []
        if command { modifiers.append("command") }
        if control { modifiers.append("control") }
        if option { modifiers.append("option") }
        if shift { modifiers.append("shift") }
        if fn { modifiers.append("fn") }

        let flags = InputControlService.resolveModifiers(modifiers)

        // Perform the key press using static method
        InputControlService.postKeyPress(resolvedKey, modifiers: flags)

        // Build display string for the key combination
        var displayModifiers: [String] = []
        if command { displayModifiers.append("Cmd") }
        if control { displayModifiers.append("Ctrl") }
        if option { displayModifiers.append("Opt") }
        if shift { displayModifiers.append("Shift") }
        if fn { displayModifiers.append("Fn") }

        let combo = displayModifiers.isEmpty ? key : "\(displayModifiers.joined(separator: "+"))+\(key)"
        let result = CommandResult.success(
            action: "key",
            details: "Pressed \(combo)"
        )
        print(result.toJSON())
    }
}

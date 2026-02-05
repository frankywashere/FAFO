import ArgumentParser
import Foundation
import AIControlCore

struct TypeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text at the current cursor position"
    )

    @Argument(help: "The text to type")
    var text: String

    @Option(name: .shortAndLong, help: "Delay in milliseconds between keystrokes")
    var delay: Int = 0

    @Flag(name: .long, help: "Press Enter after typing the text")
    var enter: Bool = false

    @MainActor
    mutating func run() async throws {
        let inputService = InputControlService()

        // Type the text
        inputService.typeText(text)

        // Additional delay between characters if specified
        if delay > 0 {
            // The InputControlService already has a built-in delay,
            // this adds extra delay if requested
            usleep(UInt32(delay * 1000))
        }

        // Press Enter if requested
        if enter {
            inputService.pressKey(.returnKey)
        }

        let details = enter
            ? "Typed \(text.count) characters and pressed Enter"
            : "Typed \(text.count) characters"

        let result = CommandResult.success(
            action: "type",
            details: details
        )
        print(result.toJSON())
    }
}

import ArgumentParser
import Foundation
import AIControlCore

struct TypeCommand: ParsableCommand {
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

    mutating func run() throws {
        // Type the text
        InputControlService.postTypeText(text)

        // Additional delay between characters if specified
        if delay > 0 {
            usleep(UInt32(delay * 1000))
        }

        // Press Enter if requested
        if enter {
            InputControlService.postKeyPress(.returnKey)
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

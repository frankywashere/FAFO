import ArgumentParser
import Foundation
import AIControlCore
import CoreGraphics

struct ScrollCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scroll",
        abstract: "Scroll at the current mouse position or specified coordinates"
    )

    @Argument(help: "Amount to scroll (positive = down/right, negative = up/left)")
    var amount: Int

    @Option(name: .shortAndLong, help: "X coordinate to scroll at (optional)")
    var x: Int?

    @Option(name: .shortAndLong, help: "Y coordinate to scroll at (optional)")
    var y: Int?

    @Flag(name: .long, help: "Scroll horizontally instead of vertically")
    var horizontal: Bool = false

    @MainActor
    mutating func run() async throws {
        let inputService = InputControlService()

        // Move mouse to position if coordinates provided
        if let x = x, let y = y {
            inputService.moveMouse(to: CGPoint(x: x, y: y))
            usleep(10000) // Small delay after moving
        }

        // Perform scroll
        if horizontal {
            inputService.scroll(deltaX: Int32(amount), deltaY: 0)
        } else {
            inputService.scroll(deltaX: 0, deltaY: Int32(amount))
        }

        let direction = horizontal ? "horizontal" : "vertical"
        let position = (x != nil && y != nil) ? " at (\(x!), \(y!))" : ""
        let result = CommandResult.success(
            action: "scroll",
            details: "Scrolled \(direction) by \(amount)\(position)"
        )
        print(result.toJSON())
    }
}

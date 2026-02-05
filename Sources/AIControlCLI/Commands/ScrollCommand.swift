import ArgumentParser
import Foundation
import AIControlCore
import CoreGraphics

struct ScrollCommand: ParsableCommand {
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

    mutating func run() throws {
        // Move mouse to position if coordinates provided
        if let x = x, let y = y {
            InputControlService.postMoveMouse(to: CGPoint(x: x, y: y))
            usleep(10000) // Small delay after moving
        }

        // Perform scroll
        if horizontal {
            InputControlService.postScroll(deltaX: Int32(amount), deltaY: 0)
        } else {
            InputControlService.postScroll(deltaX: 0, deltaY: Int32(amount))
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

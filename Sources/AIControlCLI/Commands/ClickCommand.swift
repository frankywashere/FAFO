import ArgumentParser
import Foundation
import AIControlCore
import CoreGraphics

struct ClickCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "click",
        abstract: "Perform a left mouse click at specified coordinates"
    )

    @Argument(help: "X coordinate for the click")
    var x: Int

    @Argument(help: "Y coordinate for the click")
    var y: Int

    @Option(name: .shortAndLong, help: "Delay in milliseconds before clicking")
    var delay: Int = 0

    @MainActor
    mutating func run() async throws {
        if delay > 0 {
            usleep(UInt32(delay * 1000))
        }

        let inputService = InputControlService()
        let point = CGPoint(x: x, y: y)
        inputService.click(at: point)

        let result = CommandResult.success(
            action: "click",
            details: "Clicked at (\(x), \(y))"
        )
        print(result.toJSON())
    }
}

struct RightClickCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "right-click",
        abstract: "Perform a right mouse click at specified coordinates"
    )

    @Argument(help: "X coordinate for the click")
    var x: Int

    @Argument(help: "Y coordinate for the click")
    var y: Int

    @Option(name: .shortAndLong, help: "Delay in milliseconds before clicking")
    var delay: Int = 0

    @MainActor
    mutating func run() async throws {
        if delay > 0 {
            usleep(UInt32(delay * 1000))
        }

        let inputService = InputControlService()
        let point = CGPoint(x: x, y: y)
        inputService.rightClick(at: point)

        let result = CommandResult.success(
            action: "right-click",
            details: "Right-clicked at (\(x), \(y))"
        )
        print(result.toJSON())
    }
}

struct DoubleClickCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "double-click",
        abstract: "Perform a double click at specified coordinates"
    )

    @Argument(help: "X coordinate for the click")
    var x: Int

    @Argument(help: "Y coordinate for the click")
    var y: Int

    @Option(name: .shortAndLong, help: "Delay in milliseconds before clicking")
    var delay: Int = 0

    @MainActor
    mutating func run() async throws {
        if delay > 0 {
            usleep(UInt32(delay * 1000))
        }

        let inputService = InputControlService()
        let point = CGPoint(x: x, y: y)
        inputService.doubleClick(at: point)

        let result = CommandResult.success(
            action: "double-click",
            details: "Double-clicked at (\(x), \(y))"
        )
        print(result.toJSON())
    }
}

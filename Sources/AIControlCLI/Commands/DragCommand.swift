import ArgumentParser
import Foundation
import AIControlCore
import CoreGraphics

struct DragCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "drag",
        abstract: "Perform a drag operation from one point to another"
    )

    @Argument(help: "Starting X coordinate")
    var startX: Int

    @Argument(help: "Starting Y coordinate")
    var startY: Int

    @Argument(help: "Ending X coordinate")
    var endX: Int

    @Argument(help: "Ending Y coordinate")
    var endY: Int

    @Option(name: .shortAndLong, help: "Duration of the drag in milliseconds")
    var duration: Int = 500

    @Flag(name: .long, help: "Hold Command key during drag")
    var command: Bool = false

    @Flag(name: .long, help: "Hold Option key during drag")
    var option: Bool = false

    @Flag(name: .long, help: "Hold Shift key during drag")
    var shift: Bool = false

    mutating func run() throws {
        let startPoint = CGPoint(x: startX, y: startY)
        let endPoint = CGPoint(x: endX, y: endY)
        let durationSeconds = TimeInterval(duration) / 1000.0

        // Perform the drag operation using static method
        InputControlService.postDrag(from: startPoint, to: endPoint, duration: durationSeconds)

        var modifierInfo = ""
        if command || option || shift {
            var mods: [String] = []
            if command { mods.append("Cmd") }
            if option { mods.append("Opt") }
            if shift { mods.append("Shift") }
            modifierInfo = " (modifiers: \(mods.joined(separator: "+")) requested but not yet implemented)"
        }

        let result = CommandResult.success(
            action: "drag",
            details: "Dragged from (\(startX), \(startY)) to (\(endX), \(endY)) over \(duration)ms\(modifierInfo)"
        )
        print(result.toJSON())
    }
}

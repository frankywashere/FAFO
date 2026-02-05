import ArgumentParser
import Foundation
import AIControlCore
import CoreGraphics

struct MoveMouseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move-mouse",
        abstract: "Move the mouse cursor to specified coordinates"
    )

    @Argument(help: "X coordinate to move to")
    var x: Int

    @Argument(help: "Y coordinate to move to")
    var y: Int

    @Flag(name: .long, help: "Animate the mouse movement")
    var animate: Bool = false

    @Option(name: .shortAndLong, help: "Duration of animation in milliseconds (if animated)")
    var duration: Int = 200

    mutating func run() throws {
        let targetPoint = CGPoint(x: x, y: y)

        if animate {
            // Animated movement: interpolate from current position to target
            let currentPos = InputControlService.getCursorPosition()
            let steps = max(10, duration / 10) // At least 10 steps
            let dx = (targetPoint.x - currentPos.x) / CGFloat(steps)
            let dy = (targetPoint.y - currentPos.y) / CGFloat(steps)
            let stepDelay = UInt32((duration * 1000) / steps)

            for i in 1...steps {
                let point = CGPoint(
                    x: currentPos.x + dx * CGFloat(i),
                    y: currentPos.y + dy * CGFloat(i)
                )
                InputControlService.postMoveMouse(to: point)
                usleep(stepDelay)
            }
        } else {
            InputControlService.postMoveMouse(to: targetPoint)
        }

        let result = CommandResult.success(
            action: "move-mouse",
            details: animate
                ? "Animated mouse movement to (\(x), \(y)) over \(duration)ms"
                : "Moved mouse to (\(x), \(y))"
        )
        print(result.toJSON())
    }
}

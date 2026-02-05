import ArgumentParser
import Foundation
import AppKit
import CoreGraphics
import AIControlCore

struct CalibrateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calibrate",
        abstract: "Test coordinate system accuracy by moving mouse to known points"
    )

    @Flag(name: .long, help: "Run full calibration with all test points")
    var full: Bool = false

    @Flag(name: .long, help: "Only display calibration results without making changes")
    var dryRun: Bool = false

    @Option(name: .shortAndLong, help: "Acceptable error threshold in pixels")
    var threshold: Double = 5.0

    @Option(name: .long, help: "Margin from screen edges in pixels")
    var margin: Int = 50

    mutating func run() async throws {
        // Get display dimensions
        let (width, height, _) = getDisplayInfo()

        // Define test points: center and 4 corners with margin
        let testPoints: [(String, CGPoint)] = [
            ("center", CGPoint(x: width / 2, y: height / 2)),
            ("top-left", CGPoint(x: margin, y: margin)),
            ("top-right", CGPoint(x: width - margin, y: margin)),
            ("bottom-left", CGPoint(x: margin, y: height - margin)),
            ("bottom-right", CGPoint(x: width - margin, y: height - margin)),
        ]

        var calibrationPoints: [CalibrationResult.CalibrationPoint] = []
        var errors: [Double] = []

        // Run calibration for each point
        for (label, target) in testPoints {
            if !dryRun {
                // Move mouse to target position
                moveMouseTo(target)

                // Wait for mouse to settle (100ms)
                try await Task.sleep(nanoseconds: 100_000_000)

                // Read actual cursor position
                let actual = getCursorPosition()

                // Calculate Euclidean distance error
                let error = sqrt(pow(actual.x - target.x, 2) + pow(actual.y - target.y, 2))
                errors.append(error)

                calibrationPoints.append(CalibrationResult.CalibrationPoint(
                    label: label,
                    targetX: Int(target.x),
                    targetY: Int(target.y),
                    actualX: Int(actual.x),
                    actualY: Int(actual.y),
                    error: error
                ))
            } else {
                // Dry run: simulate perfect accuracy
                calibrationPoints.append(CalibrationResult.CalibrationPoint(
                    label: label,
                    targetX: Int(target.x),
                    targetY: Int(target.y),
                    actualX: Int(target.x),
                    actualY: Int(target.y),
                    error: 0.0
                ))
                errors.append(0.0)
            }
        }

        // Calculate error statistics
        let averageError = errors.isEmpty ? 0.0 : errors.reduce(0, +) / Double(errors.count)
        let maxError = errors.max() ?? 0.0
        let passed = averageError < threshold

        let result = CalibrationResult(
            success: true,
            passed: passed,
            averageError: averageError,
            maxError: maxError,
            points: calibrationPoints,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        print(result.toJSON())
    }

    // MARK: - Helper Functions

    /// Get current cursor position using CGEvent
    private func getCursorPosition() -> CGPoint {
        return CGEvent(source: nil)?.location ?? .zero
    }

    /// Get display dimensions and scale factor from NSScreen.main
    private func getDisplayInfo() -> (width: Int, height: Int, scale: Double) {
        guard let screen = NSScreen.main else {
            return (1920, 1080, 2.0)
        }
        return (Int(screen.frame.width), Int(screen.frame.height), screen.backingScaleFactor)
    }

    /// Move mouse to specified point using CGEvent
    private func moveMouseTo(_ point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }
}

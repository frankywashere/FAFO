import ArgumentParser
import Foundation
import AIControlCore
import AppKit
import CoreGraphics

struct CaptureCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "capture",
        abstract: "Capture a screenshot of the current display"
    )

    @Option(name: .shortAndLong, help: "Output path for the screenshot (default: temp file)")
    var output: String?

    @Option(name: .shortAndLong, help: "Display index to capture (default: main display)")
    var display: Int = 0

    @Flag(name: .long, help: "Include cursor in screenshot")
    var includeCursor: Bool = false

    @Flag(name: .long, help: "Add visual grid overlay to screenshot")
    var grid: Bool = false

    mutating func run() async throws {
        do {
            // Capture screenshot using ScreenCaptureService
            let (capturedImage, displayWidth, displayHeight) = try await ScreenCaptureService.captureScreenshot(
                displayIndex: display,
                includeCursor: includeCursor
            )

            // Apply grid overlay if requested
            var finalImage = capturedImage
            if grid {
                if let gridImage = ImageUtils.drawGrid(on: capturedImage, cols: 3, rows: 2) {
                    finalImage = gridImage
                }
            }

            // Get cursor position using CGEvent
            let cursorLocation = CGEvent(source: nil)?.location ?? .zero
            let cursorX = Int(cursorLocation.x)
            let cursorY = Int(cursorLocation.y)

            // Determine output path
            let outputPath: String
            if let specifiedPath = output {
                outputPath = specifiedPath
            } else {
                outputPath = "/tmp/aicontrol_capture_\(UUID().uuidString).png"
            }

            // Convert to PNG data and save
            guard let pngData = ImageUtils.pngData(from: finalImage) else {
                let errorResult = CaptureResult(
                    success: false,
                    screenshotPath: "",
                    displayWidth: displayWidth,
                    displayHeight: displayHeight,
                    cursorX: cursorX,
                    cursorY: cursorY,
                    timestamp: ISO8601DateFormatter().string(from: Date())
                )
                print(errorResult.toJSON())
                return
            }

            try pngData.write(to: URL(fileURLWithPath: outputPath))

            // Return success result
            let result = CaptureResult(
                success: true,
                screenshotPath: outputPath,
                displayWidth: displayWidth,
                displayHeight: displayHeight,
                cursorX: cursorX,
                cursorY: cursorY,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            print(result.toJSON())

        } catch {
            // Return error result as JSON
            let errorResult = CaptureResult(
                success: false,
                screenshotPath: "Error: \(error.localizedDescription)",
                displayWidth: 0,
                displayHeight: 0,
                cursorX: 0,
                cursorY: 0,
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            print(errorResult.toJSON())
        }
    }
}

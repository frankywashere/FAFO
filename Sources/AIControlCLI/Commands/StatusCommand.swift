import ArgumentParser
import Foundation
import AppKit
import CoreGraphics
import ApplicationServices
import ScreenCaptureKit
import AIControlCore

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Get current system status and permissions"
    )

    @Flag(name: .long, help: "Include detailed permission information")
    var verbose: Bool = false

    mutating func run() async throws {
        // Get display dimensions and scale factor
        let (width, height, scale) = getDisplayInfo()

        // Get current cursor position
        let cursorPos = getCursorPosition()

        // Check accessibility permission using AXIsProcessTrusted()
        let accessibilityEnabled = AXIsProcessTrusted()

        // Check screen recording permission
        let screenRecordingEnabled = await checkScreenRecordingPermission()

        let result = StatusResult(
            success: true,
            displayWidth: width,
            displayHeight: height,
            scaleFactor: scale,
            cursorX: Int(cursorPos.x),
            cursorY: Int(cursorPos.y),
            accessibilityEnabled: accessibilityEnabled,
            screenRecordingEnabled: screenRecordingEnabled,
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

    /// Check screen recording permission by attempting to get shareable content
    private func checkScreenRecordingPermission() async -> Bool {
        do {
            // Attempt to get shareable content - this will fail if permission not granted
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }
}

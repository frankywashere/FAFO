#!/usr/bin/env swift

import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreVideo
import ApplicationServices

// MARK: - AI Computer Control System
// Proof-of-concept: Deep system integration for LLM computer control

/// High-performance screen capture and input control system optimized for AI/LLM use
@available(macOS 12.3, *)
class AIComputerControlSystem {

    // MARK: - Screen Capture Component
    class ScreenReader {
        private var stream: SCStream?
        private var isCapturing = false

        /// Frame data passed to AI for processing
        struct FrameData {
            let pixelBuffer: CVPixelBuffer
            let timestamp: CMTime
            let width: Int
            let height: Int
            let ioSurface: IOSurface?
        }

        /// Callback for frame processing
        var onFrameCaptured: ((FrameData) -> Void)?

        /// Start ultra-fast screen capture
        func startCapture() async throws {
            print("🎥 Initializing GPU-accelerated screen capture...")

            // Get display content
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            guard let display = content.displays.first else {
                throw NSError(domain: "ScreenReader", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
            }

            // Configure for maximum performance
            let streamConfig = SCStreamConfiguration()

            // Resolution: Full HD for balance of detail and performance
            // For 4K, use display.width/height directly
            streamConfig.width = 1920
            streamConfig.height = 1080

            // Target 60 FPS (can go higher on powerful machines)
            streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)

            // YUV format - GPU-native, efficient for video processing
            // Use kCVPixelFormatType_32BGRA if AI model needs RGB
            streamConfig.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

            // Queue depth prevents frame drops at high FPS
            streamConfig.queueDepth = 5

            // Cursor visibility for AI to see user interactions
            streamConfig.showsCursor = true

            // Capture entire display
            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Create stream
            stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)

            // Set up output handler
            let outputHandler = StreamOutputHandler(onFrameCaptured: onFrameCaptured)
            try stream?.addStreamOutput(
                outputHandler,
                type: .screen,
                sampleHandlerQueue: .global(qos: .userInteractive) // Highest priority
            )

            // Start capture
            try await stream?.startCapture()
            isCapturing = true
            print("✅ Screen capture active (60 FPS, GPU-accelerated)")
        }

        func stopCapture() async throws {
            guard isCapturing else { return }
            try await stream?.stopCapture()
            isCapturing = false
            print("🛑 Screen capture stopped")
        }

        // MARK: - Output Handler
        private class StreamOutputHandler: NSObject, SCStreamOutput {
            let onFrameCaptured: ((FrameData) -> Void)?

            init(onFrameCaptured: ((FrameData) -> Void)?) {
                self.onFrameCaptured = onFrameCaptured
            }

            func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
                guard type == .screen,
                      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    return
                }

                let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                // Get IOSurface for zero-copy GPU access
                let ioSurface = CVPixelBufferGetIOSurface(imageBuffer)?.takeUnretainedValue()

                let frameData = FrameData(
                    pixelBuffer: imageBuffer,
                    timestamp: timestamp,
                    width: CVPixelBufferGetWidth(imageBuffer),
                    height: CVPixelBufferGetHeight(imageBuffer),
                    ioSurface: ioSurface
                )

                onFrameCaptured?(frameData)
            }
        }
    }

    // MARK: - Input Control Component
    class InputController {

        /// Check if input control permissions are granted
        static func checkPermissions() -> Bool {
            let trusted = AXIsProcessTrusted()
            if !trusted {
                print("⚠️  Accessibility permissions required!")
                print("   → System Settings → Privacy & Security → Accessibility")
            }
            return trusted
        }

        /// Move mouse to absolute screen coordinates
        func moveMouse(to point: CGPoint) {
            let moveEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .mouseMoved,
                mouseCursorPosition: point,
                mouseButton: .left
            )
            moveEvent?.post(tap: .cghidEventTap)
        }

        /// Click at current mouse position
        func click() {
            let currentLocation = CGEvent(source: nil)?.location ?? .zero

            let mouseDown = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: currentLocation,
                mouseButton: .left
            )

            let mouseUp = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: currentLocation,
                mouseButton: .left
            )

            mouseDown?.post(tap: .cghidEventTap)
            mouseUp?.post(tap: .cghidEventTap)
        }

        /// Click at specific coordinates
        func click(at point: CGPoint) {
            moveMouse(to: point)
            usleep(10_000) // 10ms delay for cursor to settle
            click()
        }

        /// Type text using keyboard events
        func typeText(_ text: String) {
            let source = CGEventSource(stateID: .combinedSessionState)

            for character in text.unicodeScalars {
                let keyCode: CGKeyCode = 0 // Virtual key
                let unichar = UniChar(character.value)

                let keyDown = CGEvent(
                    keyboardEventSource: source,
                    virtualKey: keyCode,
                    keyDown: true
                )
                keyDown?.keyboardSetUnicodeString(
                    stringLength: 1,
                    unicodeString: [unichar]
                )

                let keyUp = CGEvent(
                    keyboardEventSource: source,
                    virtualKey: keyCode,
                    keyDown: false
                )
                keyUp?.keyboardSetUnicodeString(
                    stringLength: 1,
                    unicodeString: [unichar]
                )

                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        }

        /// Press specific key (using key codes)
        func pressKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
            let source = CGEventSource(stateID: .combinedSessionState)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            keyDown?.flags = modifiers

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }

        /// Common key codes
        enum Key: CGKeyCode {
            case return_ = 36
            case tab = 48
            case space = 49
            case delete = 51
            case escape = 53
            case command = 55
            case shift = 56
            case capsLock = 57
            case option = 58
            case control = 59

            // Arrow keys
            case leftArrow = 123
            case rightArrow = 124
            case downArrow = 125
            case upArrow = 126
        }
    }

    // MARK: - AI Processing Pipeline
    class AIProcessor {

        /// Process frame and extract data for LLM
        func processFrame(_ frameData: ScreenReader.FrameData) async -> ProcessedFrame {
            let startTime = Date()

            // Lock pixel buffer for CPU access
            CVPixelBufferLockBaseAddress(frameData.pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(frameData.pixelBuffer, .readOnly) }

            // Extract pixel data
            // In production, you'd:
            // 1. Convert to format AI model expects (RGB, normalized, etc.)
            // 2. Resize if needed
            // 3. Run through vision model to extract UI elements
            // 4. OCR text content
            // 5. Identify clickable elements

            let processingTime = Date().timeIntervalSince(startTime)

            return ProcessedFrame(
                timestamp: frameData.timestamp,
                width: frameData.width,
                height: frameData.height,
                processingTimeMS: processingTime * 1000,
                elements: [] // Would contain detected UI elements
            )
        }

        struct ProcessedFrame {
            let timestamp: CMTime
            let width: Int
            let height: Int
            let processingTimeMS: Double
            let elements: [UIElement]
        }

        struct UIElement {
            let type: String // button, text field, window, etc.
            let bounds: CGRect
            let text: String?
            let isClickable: Bool
        }
    }

    // MARK: - Main Control Loop
    private let screenReader = ScreenReader()
    private let inputController = InputController()
    private let aiProcessor = AIProcessor()

    private var frameCount = 0
    private var totalProcessingTime: TimeInterval = 0

    func start() async throws {
        print("🤖 AI Computer Control System")
        print("=" * 60)

        // Check permissions
        guard InputController.checkPermissions() else {
            throw NSError(domain: "AIControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing permissions"])
        }

        // Set up frame processing
        screenReader.onFrameCaptured = { [weak self] frameData in
            Task {
                guard let self = self else { return }

                // Process frame
                let processed = await self.aiProcessor.processFrame(frameData)

                // Update stats
                self.frameCount += 1
                self.totalProcessingTime += processed.processingTimeMS / 1000

                // Log performance every 60 frames
                if self.frameCount % 60 == 0 {
                    let avgProcessingTime = self.totalProcessingTime / Double(self.frameCount)
                    print(String(format: "📊 Frames: %d | Avg Processing: %.2f ms", self.frameCount, avgProcessingTime * 1000))
                }

                // Here's where you'd send frame to LLM and execute actions
                // Example: await self.sendToLLM(processed)
            }
        }

        // Start screen capture
        try await screenReader.startCapture()

        print("✅ System active - AI can now see and control the computer")
        print("   Press Ctrl+C to stop")
    }

    func stop() async throws {
        try await screenReader.stopCapture()
        print("🛑 System stopped")
    }

    // MARK: - Demo Actions
    func demoInputControl() {
        print("\n🎮 Demonstrating input control...")

        // Move mouse to center of screen
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        let center = CGPoint(
            x: screenBounds.width / 2,
            y: screenBounds.height / 2
        )

        inputController.moveMouse(to: center)
        print("   ✓ Moved mouse to screen center: \(center)")

        // Type text
        inputController.typeText("Hello from AI!")
        print("   ✓ Typed text")

        // Press key
        inputController.pressKey(InputController.Key.return_.rawValue)
        print("   ✓ Pressed Return key")
    }
}

// MARK: - String Extension
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// MARK: - Main Entry Point
@main
struct AIControlDemo {
    static func main() async {
        if #available(macOS 12.3, *) {
            let system = AIComputerControlSystem()

            do {
                // Start system
                try await system.start()

                // Run for 10 seconds
                try await Task.sleep(nanoseconds: 10_000_000_000)

                // Demo input control
                system.demoInputControl()

                // Stop system
                try await system.stop()

            } catch {
                print("❌ Error: \(error)")
            }
        } else {
            print("⚠️  Requires macOS 12.3 or later for ScreenCaptureKit")
        }
    }
}

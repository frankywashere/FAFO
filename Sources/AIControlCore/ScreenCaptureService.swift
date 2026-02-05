import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreVideo
import AppKit

public struct CapturedFrame {
    public let image: CGImage?
    public let timestamp: Date
    public let width: Int
    public let height: Int
    public let frameNumber: UInt64

    public init(image: CGImage?, timestamp: Date, width: Int, height: Int, frameNumber: UInt64) {
        self.image = image
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.frameNumber = frameNumber
    }

    public var pngData: Data? {
        guard let image = image else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }

    public var jpegData: Data? {
        guard let image = image else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}

@MainActor
public final class ScreenCaptureService: NSObject, ObservableObject {
    @Published public var isCapturing = false
    @Published public var currentFrame: CapturedFrame?
    @Published public var fps: Double = 0
    @Published public var latencyMs: Double = 0
    @Published public var error: String?
    @Published public var displayPointWidth: Int = 0
    @Published public var displayPointHeight: Int = 0
    public var excludeOwnWindows = true
    public var excludeTerminalWindows = true

    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var frameCount: UInt64 = 0
    private var fpsTimer: Date = Date()
    private var fpsFrameCount: Int = 0

    public var onFrameCaptured: ((CapturedFrame) -> Void)?

    public override init() {
        super.init()
    }

    public func startCapture() async {
        guard !isCapturing else { return }

        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = availableContent.displays.first else {
                error = "No display found"
                return
            }

            // Build exclusion list based on configuration
            var excludedWindows: [SCWindow] = []
            Log.info("Capture exclusion settings: excludeOwnWindows=\(excludeOwnWindows), excludeTerminalWindows=\(excludeTerminalWindows)")

            if excludeOwnWindows {
                let ownPID = ProcessInfo.processInfo.processIdentifier
                let ownWindows = availableContent.windows.filter { $0.owningApplication?.processID == ownPID }
                excludedWindows.append(contentsOf: ownWindows)
                if !ownWindows.isEmpty {
                    Log.info("Excluding \(ownWindows.count) own window(s) from capture (PID \(ownPID))")
                }
            }

            if excludeTerminalWindows {
                let terminalWindows = availableContent.windows.filter {
                    $0.owningApplication?.bundleIdentifier == "com.apple.Terminal"
                }
                excludedWindows.append(contentsOf: terminalWindows)
                if !terminalWindows.isEmpty {
                    Log.info("Excluding \(terminalWindows.count) Terminal.app window(s) from capture")
                }
            }

            if excludedWindows.isEmpty {
                Log.info("Capturing all windows (no exclusions)")
            }

            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

            self.displayPointWidth = Int(display.width)
            self.displayPointHeight = Int(display.height)
            Log.info("Display point dimensions: \(displayPointWidth)x\(displayPointHeight)")

            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.queueDepth = 5
            config.showsCursor = true
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let stream = SCStream(filter: filter, configuration: config, delegate: nil)

            let output = StreamOutput { [weak self] frame in
                Task { @MainActor in
                    self?.handleFrame(frame)
                }
            }

            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.aicontrol.capture", qos: .userInteractive))
            try await stream.startCapture()

            self.stream = stream
            self.streamOutput = output
            self.isCapturing = true
            self.error = nil
            self.fpsTimer = Date()
            self.fpsFrameCount = 0

        } catch {
            self.error = "Capture failed: \(error.localizedDescription)"
        }
    }

    public func stopCapture() async {
        guard isCapturing, let stream = stream else { return }

        do {
            try await stream.stopCapture()
        } catch {
            // Ignore stop errors
        }

        self.stream = nil
        self.streamOutput = nil
        self.isCapturing = false
    }

    private func handleFrame(_ frame: CapturedFrame) {
        frameCount += 1
        fpsFrameCount += 1

        let now = Date()
        let elapsed = now.timeIntervalSince(fpsTimer)
        if elapsed >= 1.0 {
            fps = Double(fpsFrameCount) / elapsed
            fpsFrameCount = 0
            fpsTimer = now
        }

        latencyMs = now.timeIntervalSince(frame.timestamp) * 1000

        currentFrame = frame
        onFrameCaptured?(frame)
    }

    /// Capture a single screenshot (non-streaming)
    public static func captureScreenshot(displayIndex: Int = 0, includeCursor: Bool = true) async throws -> (CGImage, Int, Int) {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard displayIndex < availableContent.displays.count else {
            throw NSError(domain: "ScreenCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Display index out of range"])
        }

        let display = availableContent.displays[displayIndex]
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.showsCursor = includeCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        return (image, Int(display.width), Int(display.height))
    }
}

private class StreamOutput: NSObject, SCStreamOutput {
    let handler: (CapturedFrame) -> Void
    private let ciContext = CIContext()
    private var frameCounter: UInt64 = 0

    init(handler: @escaping (CapturedFrame) -> Void) {
        self.handler = handler
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let timestamp = Date()
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Create CGImage from pixel buffer using reusable CIContext
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)

        frameCounter += 1

        let frame = CapturedFrame(
            image: cgImage,
            timestamp: timestamp,
            width: width,
            height: height,
            frameNumber: frameCounter
        )

        handler(frame)
    }
}

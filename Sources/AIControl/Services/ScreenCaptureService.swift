import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreVideo
import AppKit

struct CapturedFrame {
    let image: CGImage?
    let timestamp: Date
    let width: Int
    let height: Int
    let frameNumber: UInt64

    var pngData: Data? {
        guard let image = image else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }

    var jpegData: Data? {
        guard let image = image else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}

@MainActor
final class ScreenCaptureService: NSObject, ObservableObject {
    @Published var isCapturing = false
    @Published var currentFrame: CapturedFrame?
    @Published var fps: Double = 0
    @Published var latencyMs: Double = 0
    @Published var error: String?

    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var frameCount: UInt64 = 0
    private var fpsTimer: Date = Date()
    private var fpsFrameCount: Int = 0

    var onFrameCaptured: ((CapturedFrame) -> Void)?

    func startCapture() async {
        guard !isCapturing else { return }

        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = availableContent.displays.first else {
                error = "No display found"
                return
            }

            // Exclude our own app windows so the AI doesn't see a recursive mirror
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let ownWindows = availableContent.windows.filter { $0.owningApplication?.processID == ownPID }
            if !ownWindows.isEmpty {
                Log.info("Excluding \(ownWindows.count) own window(s) from capture (PID \(ownPID))")
            }
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)

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

    func stopCapture() async {
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

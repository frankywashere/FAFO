import SwiftUI
import AppKit

struct CanvasView: View {
    let frame: CapturedFrame?
    let fps: Double
    let latencyMs: Double
    @Binding var showOverlay: Bool
    @Binding var overlayAnnotations: [CanvasAnnotation]
    @Binding var hidePreview: Bool

    var body: some View {
        ZStack {
            // Background
            Color.black

            if hidePreview {
                // Blacked out — capture still runs but preview is hidden
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("Preview Hidden")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.4))
                    if frame != nil {
                        Text("Capture is still running")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
            } else if let frame = frame, let cgImage = frame.image {
                // Screen capture display
                Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay {
                        if showOverlay {
                            AnnotationOverlay(annotations: overlayAnnotations)
                        }
                    }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "display")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No Screen Capture")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Click 'Start Capture' to begin")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }

            // Stats overlay
            VStack {
                HStack {
                    Spacer()
                    StatsOverlay(fps: fps, latencyMs: latencyMs, hasFrame: frame != nil)
                        .padding(8)
                }
                Spacer()
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CanvasAnnotation: Identifiable {
    let id = UUID()
    let rect: CGRect
    let label: String
    let color: Color
}

struct AnnotationOverlay: View {
    let annotations: [CanvasAnnotation]

    var body: some View {
        GeometryReader { geo in
            ForEach(annotations) { annotation in
                let scaledRect = scaleRect(annotation.rect, to: geo.size)
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .stroke(annotation.color, lineWidth: 2)
                        .frame(width: scaledRect.width, height: scaledRect.height)

                    Text(annotation.label)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(annotation.color.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .offset(y: -20)
                }
                .position(x: scaledRect.midX, y: scaledRect.midY)
            }
        }
    }

    private func scaleRect(_ rect: CGRect, to size: CGSize) -> CGRect {
        return CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }
}

struct StatsOverlay: View {
    let fps: Double
    let latencyMs: Double
    let hasFrame: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(hasFrame ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(hasFrame ? "LIVE" : "OFF")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(hasFrame ? .green : .red)
            }

            if hasFrame {
                Text("\(String(format: "%.1f", fps)) FPS")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                Text("\(String(format: "%.1f", latencyMs)) ms")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(6)
    }
}

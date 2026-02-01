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
                            AnnotationOverlay(
                                annotations: overlayAnnotations,
                                imageAspectRatio: CGFloat(cgImage.width) / CGFloat(cgImage.height)
                            )
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
    let rect: CGRect   // Normalized 0-1 coordinates relative to screen
    let label: String
    let color: Color
    let point: CGPoint? // Optional center point for point-based annotations (clicks)

    init(rect: CGRect, label: String, color: Color, point: CGPoint? = nil) {
        self.rect = rect
        self.label = label
        self.color = color
        self.point = point
    }

    /// Create annotation from absolute screen coordinates (auto-normalizes)
    static func fromScreenPoint(x: Int, y: Int, screenWidth: Int, screenHeight: Int, label: String, color: Color) -> CanvasAnnotation {
        let markerSize: CGFloat = 30
        let normX = CGFloat(x) / CGFloat(screenWidth)
        let normY = CGFloat(y) / CGFloat(screenHeight)
        let normW = markerSize / CGFloat(screenWidth)
        let normH = markerSize / CGFloat(screenHeight)
        return CanvasAnnotation(
            rect: CGRect(x: normX - normW / 2, y: normY - normH / 2, width: normW, height: normH),
            label: label,
            color: color,
            point: CGPoint(x: normX, y: normY)
        )
    }

    /// Create annotation from absolute screen rect
    static func fromScreenRect(x: Int, y: Int, toX: Int, toY: Int, screenWidth: Int, screenHeight: Int, label: String, color: Color) -> CanvasAnnotation {
        let normX = CGFloat(min(x, toX)) / CGFloat(screenWidth)
        let normY = CGFloat(min(y, toY)) / CGFloat(screenHeight)
        let normW = CGFloat(abs(toX - x)) / CGFloat(screenWidth)
        let normH = CGFloat(abs(toY - y)) / CGFloat(screenHeight)
        return CanvasAnnotation(
            rect: CGRect(x: normX, y: normY, width: max(normW, 0.01), height: max(normH, 0.01)),
            label: label,
            color: color
        )
    }
}

struct AnnotationOverlay: View {
    let annotations: [CanvasAnnotation]
    var imageAspectRatio: CGFloat = 16.0 / 9.0  // default fallback

    var body: some View {
        GeometryReader { geo in
            // Compute the actual image rect within this view, accounting for
            // aspect-fit letterboxing (black bars on sides or top/bottom)
            let imageRect = fittedImageRect(in: geo.size, imageAspect: imageAspectRatio)

            ForEach(annotations) { annotation in
                if let point = annotation.point {
                    // Point-based annotation: crosshair + label
                    let scaledX = imageRect.origin.x + point.x * imageRect.width
                    let scaledY = imageRect.origin.y + point.y * imageRect.height
                    ZStack {
                        // Crosshair
                        CrosshairShape()
                            .stroke(annotation.color, lineWidth: 2)
                            .frame(width: 24, height: 24)
                        // Pulsing circle
                        Circle()
                            .fill(annotation.color.opacity(0.3))
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(annotation.color, lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                        // Label
                        Text(annotation.label)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(annotation.color.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                            .offset(y: -22)
                    }
                    .position(x: scaledX, y: scaledY)
                } else {
                    // Rect-based annotation: box + label
                    let scaledRect = scaleRect(annotation.rect, within: imageRect)
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
    }

    /// Compute the fitted image rectangle within the available view size,
    /// accounting for aspect-fit letterboxing.
    private func fittedImageRect(in viewSize: CGSize, imageAspect: CGFloat) -> CGRect {
        let viewAspect = viewSize.width / viewSize.height
        if imageAspect > viewAspect {
            // Image is wider than view: letterbox top/bottom
            let height = viewSize.width / imageAspect
            let y = (viewSize.height - height) / 2
            return CGRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            // Image is taller than view: letterbox left/right
            let width = viewSize.height * imageAspect
            let x = (viewSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: viewSize.height)
        }
    }

    private func scaleRect(_ rect: CGRect, within imageRect: CGRect) -> CGRect {
        return CGRect(
            x: imageRect.origin.x + rect.origin.x * imageRect.width,
            y: imageRect.origin.y + rect.origin.y * imageRect.height,
            width: rect.width * imageRect.width,
            height: rect.height * imageRect.height
        )
    }
}

/// Crosshair shape for click annotations
struct CrosshairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Horizontal line
        path.move(to: CGPoint(x: rect.minX, y: center.y))
        path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
        // Vertical line
        path.move(to: CGPoint(x: center.x, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
        return path
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

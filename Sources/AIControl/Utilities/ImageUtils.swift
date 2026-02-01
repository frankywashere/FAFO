import Foundation
import AppKit
import CoreGraphics

struct LetterboxInfo {
    let canvasWidth: Int      // e.g. 1344
    let canvasHeight: Int     // e.g. 896
    let imageWidth: Int       // actual scaled image width inside canvas
    let imageHeight: Int      // actual scaled image height inside canvas
    let offsetX: Int          // horizontal padding (left side)
    let offsetY: Int          // vertical padding (top side)
}

enum ImageUtils {
    /// Convert CGImage to PNG data
    static func pngData(from cgImage: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    /// Convert CGImage to JPEG data with quality 0-1
    static func jpegData(from cgImage: CGImage, quality: CGFloat = 0.8) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    /// Resize a CGImage to fit within maxDimension (preserving aspect ratio)
    static func resize(_ cgImage: CGImage, maxDimension: Int) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        let maxCurrent = max(width, height)

        if maxCurrent <= maxDimension { return cgImage }

        let scale = CGFloat(maxDimension) / CGFloat(maxCurrent)
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }

    /// Convert CGImage to base64 PNG string
    static func base64PNG(from cgImage: CGImage, maxDimension: Int = 1920) -> String? {
        let resized = resize(cgImage, maxDimension: maxDimension) ?? cgImage
        guard let data = pngData(from: resized) else { return nil }
        return data.base64EncodedString()
    }

    /// Resize image to fit within a canvas (letterboxed with black bars), returning both the image and letterbox info
    static func resizeToCanvas(_ cgImage: CGImage, targetWidth: Int, targetHeight: Int) -> (CGImage, LetterboxInfo)? {
        let srcW = CGFloat(cgImage.width)
        let srcH = CGFloat(cgImage.height)
        let tgtW = CGFloat(targetWidth)
        let tgtH = CGFloat(targetHeight)

        // Scale proportionally to fit within target dimensions
        let scale = min(tgtW / srcW, tgtH / srcH, 1.0)
        let scaledW = Int(srcW * scale)
        let scaledH = Int(srcH * scale)

        // Center on canvas
        let offsetX = (targetWidth - scaledW) / 2
        let offsetY = (targetHeight - scaledH) / 2

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Fill with black (letterbox bars)
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Draw image centered (CGContext has flipped Y: origin is bottom-left)
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: offsetX, y: targetHeight - offsetY - scaledH, width: scaledW, height: scaledH))

        guard let resultImage = context.makeImage() else { return nil }

        let info = LetterboxInfo(
            canvasWidth: targetWidth,
            canvasHeight: targetHeight,
            imageWidth: scaledW,
            imageHeight: scaledH,
            offsetX: offsetX,
            offsetY: offsetY
        )

        return (resultImage, info)
    }

    /// Draw a crosshair marker on an image at the given pixel coordinates (for reverse calibration)
    static func drawMarker(on cgImage: CGImage, atX x: Int, atY y: Int, size: CGFloat = 30, lineWidth: CGFloat = 3) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw original image (CGContext origin is bottom-left, so Y is flipped)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Flip to top-left origin for drawing
        let flippedY = CGFloat(height - y)

        // Draw red crosshair
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(lineWidth)

        let half = size / 2
        let cx = CGFloat(x)

        // Horizontal line
        context.move(to: CGPoint(x: cx - half, y: flippedY))
        context.addLine(to: CGPoint(x: cx + half, y: flippedY))
        context.strokePath()

        // Vertical line
        context.move(to: CGPoint(x: cx, y: flippedY - half))
        context.addLine(to: CGPoint(x: cx, y: flippedY + half))
        context.strokePath()

        // Draw circle
        let circleRect = CGRect(x: cx - half / 2, y: flippedY - half / 2, width: half, height: half)
        context.strokeEllipse(in: circleRect)

        return context.makeImage()
    }

    /// Draw a labeled 3x2 grid (448x448 tiles) on a 1344x896 canvas for tile-based coordinate mode
    static func drawGrid(on cgImage: CGImage, cols: Int = 3, rows: Int = 2) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw original image (CGContext origin is bottom-left)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let tileW = width / cols
        let tileH = height / rows

        // Draw grid lines (cyan, semi-transparent)
        context.setStrokeColor(CGColor(red: 0, green: 1, blue: 1, alpha: 0.7))
        context.setLineWidth(2)

        // Vertical lines
        for col in 1..<cols {
            let x = CGFloat(col * tileW)
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: CGFloat(height)))
            context.strokePath()
        }

        // Horizontal lines
        for row in 1..<rows {
            // CGContext Y is flipped: 0 is bottom, height is top
            let y = CGFloat(height - row * tileH)
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: CGFloat(width), y: y))
            context.strokePath()
        }

        // Draw tile labels (A1, A2, A3, B1, B2, B3)
        let rowLabels = ["A", "B"]  // top row = A, bottom row = B
        let fontSize: CGFloat = 28

        for row in 0..<rows {
            for col in 0..<cols {
                let label = "\(rowLabels[row])\(col + 1)"
                let labelX = CGFloat(col * tileW) + 8
                // CGContext flipped Y: top-left of row 0 = height - fontSize - 8
                let labelY = CGFloat(height) - CGFloat(row * tileH) - fontSize - 8

                // Draw label background
                let bgRect = CGRect(x: labelX - 2, y: labelY - 4, width: fontSize * 1.8, height: fontSize + 8)
                context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
                context.fill(bgRect)

                // Draw label text using Core Text
                let attrString = NSAttributedString(
                    string: label,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                        .foregroundColor: NSColor.cyan
                    ]
                )
                let line = CTLineCreateWithAttributedString(attrString)
                context.textPosition = CGPoint(x: labelX, y: labelY)
                CTLineDraw(line, context)
            }
        }

        // ── Coordinate tick marks with numerical labels ──
        // Draws ruler-style tick marks every 100px on all four edges.
        // CGContext note: origin is bottom-left, so screen-Y must be flipped.

        let tickInterval = 100        // pixels between ticks
        let tickLength: CGFloat = 10  // tick line length in pixels
        let tickFontSize: CGFloat = 12
        let tickLineWidth: CGFloat = 1.5
        let tickColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.9)         // white ticks
        let tickLabelColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.95)   // white text
        let tickBgColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.55)      // dark semi-transparent bg

        let tickFont = NSFont.monospacedDigitSystemFont(ofSize: tickFontSize, weight: .medium)

        // Helper: create a CTLine for a tick label string and measure its width
        func makeTickLabel(_ text: String) -> (CTLine, CGFloat) {
            let attr = NSAttributedString(
                string: text,
                attributes: [
                    .font: tickFont,
                    .foregroundColor: tickLabelColor
                ]
            )
            let ctLine = CTLineCreateWithAttributedString(attr)
            let bounds = CTLineGetBoundsWithOptions(ctLine, [])
            return (ctLine, bounds.width)
        }

        context.setStrokeColor(tickColor)
        context.setLineWidth(tickLineWidth)

        // ── Top edge ticks (screen top = CGContext y near `height`) ──
        for px in stride(from: 0, through: width, by: tickInterval) {
            let x = CGFloat(px)
            let topY = CGFloat(height)      // top of canvas in CG coords

            // Tick line extending downward from top edge
            context.move(to: CGPoint(x: x, y: topY))
            context.addLine(to: CGPoint(x: x, y: topY - tickLength))
            context.strokePath()

            // Label below the tick
            let (ctLine, textW) = makeTickLabel("\(px)")
            let textX = x - textW / 2  // center label on tick
            let textY = topY - tickLength - tickFontSize - 4  // below the tick line

            // Background rect behind label
            let bgW = textW + 4
            let bgH = tickFontSize + 4
            let bgX = textX - 2
            let bgY = textY - 2
            context.setFillColor(tickBgColor)
            context.fill(CGRect(x: bgX, y: bgY, width: bgW, height: bgH))

            context.textPosition = CGPoint(x: textX, y: textY)
            CTLineDraw(ctLine, context)
        }

        // ── Bottom edge ticks (screen bottom = CGContext y near 0) ──
        for px in stride(from: 0, through: width, by: tickInterval) {
            let x = CGFloat(px)
            let bottomY: CGFloat = 0  // bottom of canvas in CG coords

            // Tick line extending upward from bottom edge
            context.setStrokeColor(tickColor)
            context.setLineWidth(tickLineWidth)
            context.move(to: CGPoint(x: x, y: bottomY))
            context.addLine(to: CGPoint(x: x, y: bottomY + tickLength))
            context.strokePath()

            // Label above the tick
            let (ctLine, textW) = makeTickLabel("\(px)")
            let textX = x - textW / 2
            let textY = bottomY + tickLength + 4

            let bgW = textW + 4
            let bgH = tickFontSize + 4
            let bgX = textX - 2
            let bgY = textY - 2
            context.setFillColor(tickBgColor)
            context.fill(CGRect(x: bgX, y: bgY, width: bgW, height: bgH))

            context.textPosition = CGPoint(x: textX, y: textY)
            CTLineDraw(ctLine, context)
        }

        // ── Left edge ticks (screen left = CGContext x near 0) ──
        for py in stride(from: 0, through: height, by: tickInterval) {
            // py is in screen coords (top-left origin). Convert to CG coords.
            let cgY = CGFloat(height - py)
            let leftX: CGFloat = 0

            // Tick line extending rightward from left edge
            context.setStrokeColor(tickColor)
            context.setLineWidth(tickLineWidth)
            context.move(to: CGPoint(x: leftX, y: cgY))
            context.addLine(to: CGPoint(x: leftX + tickLength, y: cgY))
            context.strokePath()

            // Label to the right of the tick
            let (ctLine, textW) = makeTickLabel("\(py)")
            let textX = leftX + tickLength + 4
            let textY = cgY - tickFontSize / 2  // vertically center on tick

            let bgW = textW + 4
            let bgH = tickFontSize + 4
            let bgX = textX - 2
            let bgY = textY - 2
            context.setFillColor(tickBgColor)
            context.fill(CGRect(x: bgX, y: bgY, width: bgW, height: bgH))

            context.textPosition = CGPoint(x: textX, y: textY)
            CTLineDraw(ctLine, context)
        }

        // ── Right edge ticks (screen right = CGContext x near `width`) ──
        for py in stride(from: 0, through: height, by: tickInterval) {
            let cgY = CGFloat(height - py)
            let rightX = CGFloat(width)

            // Tick line extending leftward from right edge
            context.setStrokeColor(tickColor)
            context.setLineWidth(tickLineWidth)
            context.move(to: CGPoint(x: rightX, y: cgY))
            context.addLine(to: CGPoint(x: rightX - tickLength, y: cgY))
            context.strokePath()

            // Label to the left of the tick
            let (ctLine, textW) = makeTickLabel("\(py)")
            let textX = rightX - tickLength - textW - 4
            let textY = cgY - tickFontSize / 2

            let bgW = textW + 4
            let bgH = tickFontSize + 4
            let bgX = textX - 2
            let bgY = textY - 2
            context.setFillColor(tickBgColor)
            context.fill(CGRect(x: bgX, y: bgY, width: bgW, height: bgH))

            context.textPosition = CGPoint(x: textX, y: textY)
            CTLineDraw(ctLine, context)
        }

        return context.makeImage()
    }

    /// Convert NSImage to CGImage
    static func cgImage(from nsImage: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: nsImage.size)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// Create NSImage from CGImage
    static func nsImage(from cgImage: CGImage) -> NSImage {
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

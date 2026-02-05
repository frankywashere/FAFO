import Foundation
import AppKit
import CoreGraphics

public struct LetterboxInfo {
    public let canvasWidth: Int      // e.g. 1344
    public let canvasHeight: Int     // e.g. 896
    public let imageWidth: Int       // actual scaled image width inside canvas
    public let imageHeight: Int      // actual scaled image height inside canvas
    public let offsetX: Int          // horizontal padding (left side)
    public let offsetY: Int          // vertical padding (top side)

    public init(canvasWidth: Int, canvasHeight: Int, imageWidth: Int, imageHeight: Int, offsetX: Int, offsetY: Int) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

public enum ImageUtils {
    /// Convert CGImage to PNG data
    public static func pngData(from cgImage: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    /// Convert CGImage to JPEG data with quality 0-1
    public static func jpegData(from cgImage: CGImage, quality: CGFloat = 0.8) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    /// Resize a CGImage to fit within maxDimension (preserving aspect ratio)
    public static func resize(_ cgImage: CGImage, maxDimension: Int) -> CGImage? {
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
    public static func base64PNG(from cgImage: CGImage, maxDimension: Int = 1920) -> String? {
        let resized = resize(cgImage, maxDimension: maxDimension) ?? cgImage
        guard let data = pngData(from: resized) else { return nil }
        return data.base64EncodedString()
    }

    /// Resize image to fit within a canvas (letterboxed with black bars), returning both the image and letterbox info
    public static func resizeToCanvas(_ cgImage: CGImage, targetWidth: Int, targetHeight: Int) -> (CGImage, LetterboxInfo)? {
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
    public static func drawMarker(on cgImage: CGImage, atX x: Int, atY y: Int, size: CGFloat = 30, lineWidth: CGFloat = 3) -> CGImage? {
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
    public static func drawGrid(on cgImage: CGImage, cols: Int = 3, rows: Int = 2) -> CGImage? {
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

        return context.makeImage()
    }

    /// Convert NSImage to CGImage
    public static func cgImage(from nsImage: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: nsImage.size)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// Create NSImage from CGImage
    public static func nsImage(from cgImage: CGImage) -> NSImage {
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

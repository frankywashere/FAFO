import Foundation
import AppKit
import CoreGraphics

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

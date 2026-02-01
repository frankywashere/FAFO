// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIControl",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AIControl",
            path: "Sources/AIControl",
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
            ]
        )
    ]
)

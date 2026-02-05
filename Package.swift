// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AIControlCore", targets: ["AIControlCore"]),
        .executable(name: "AIControlCLI", targets: ["AIControlCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        // Shared library with core services (screen capture, input control, utilities)
        .target(
            name: "AIControlCore",
            path: "Sources/AIControlCore",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
            ]
        ),
        // CLI executable
        .executableTarget(
            name: "AIControlCLI",
            dependencies: [
                "AIControlCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/AIControlCLI",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        // Main GUI app (may have compile errors due to missing LLM files)
        .executableTarget(
            name: "AIControl",
            dependencies: ["AIControlCore"],
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

import ArgumentParser
import Foundation
import AIControlCore

struct OpenAppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open-app",
        abstract: "Open an application by name or bundle identifier"
    )

    @Argument(help: "Application name or bundle identifier")
    var app: String

    @Flag(name: .long, help: "Wait for the app to launch before returning")
    var wait: Bool = false

    @Option(name: .shortAndLong, help: "Timeout in seconds when waiting")
    var timeout: Int = 10

    @MainActor
    mutating func run() async throws {
        let inputService = InputControlService()
        inputService.openApplication(app)

        if wait {
            // Wait for the app to become active
            let deadline = Date().addingTimeInterval(TimeInterval(timeout))
            var launched = false

            while Date() < deadline {
                // Check if the app is now running and focused
                if inputService.focusApplication(app) {
                    launched = true
                    break
                }
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            }

            if launched {
                let result = CommandResult.success(
                    action: "open-app",
                    details: "Opened and focused application: \(app)"
                )
                print(result.toJSON())
            } else {
                let result = CommandResult.failure(
                    action: "open-app",
                    error: "Application '\(app)' did not launch within \(timeout) seconds"
                )
                print(result.toJSON())
            }
        } else {
            let result = CommandResult.success(
                action: "open-app",
                details: "Opened application: \(app)"
            )
            print(result.toJSON())
        }
    }
}

struct FocusAppCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus-app",
        abstract: "Bring an application to the foreground"
    )

    @Argument(help: "Application name or bundle identifier")
    var app: String

    @MainActor
    mutating func run() async throws {
        let inputService = InputControlService()
        let success = inputService.focusApplication(app)

        if success {
            let result = CommandResult.success(
                action: "focus-app",
                details: "Focused application: \(app)"
            )
            print(result.toJSON())
        } else {
            let result = CommandResult.failure(
                action: "focus-app",
                error: "Could not focus application '\(app)'. Make sure it is running."
            )
            print(result.toJSON())
        }
    }
}

struct ShowDesktopCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show-desktop",
        abstract: "Show the desktop by minimizing all windows"
    )

    @MainActor
    mutating func run() async throws {
        let inputService = InputControlService()
        inputService.showDesktop()

        let result = CommandResult.success(
            action: "show-desktop",
            details: "Desktop shown (toggled Fn+F11)"
        )
        print(result.toJSON())
    }
}

import ArgumentParser
import Foundation
import AIControlCore

struct OpenAppCommand: ParsableCommand {
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

    mutating func run() throws {
        let success = InputControlService.postOpenApp(app)

        if wait && success {
            // Wait for the app to become active
            let deadline = Date().addingTimeInterval(TimeInterval(timeout))
            var focused = false

            while Date() < deadline {
                if InputControlService.postFocusApp(app) {
                    focused = true
                    break
                }
                Thread.sleep(forTimeInterval: 0.5) // 500ms
            }

            if focused {
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
        } else if success {
            let result = CommandResult.success(
                action: "open-app",
                details: "Opened application: \(app)"
            )
            print(result.toJSON())
        } else {
            let result = CommandResult.failure(
                action: "open-app",
                error: "Failed to open application: \(app)"
            )
            print(result.toJSON())
        }
    }
}

struct FocusAppCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus-app",
        abstract: "Bring an application to the foreground"
    )

    @Argument(help: "Application name or bundle identifier")
    var app: String

    mutating func run() throws {
        let success = InputControlService.postFocusApp(app)

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

struct ShowDesktopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show-desktop",
        abstract: "Show the desktop by minimizing all windows"
    )

    mutating func run() throws {
        InputControlService.postShowDesktop()

        let result = CommandResult.success(
            action: "show-desktop",
            details: "Desktop shown (toggled Fn+F11)"
        )
        print(result.toJSON())
    }
}

import ArgumentParser
import Foundation

@main
struct AIControlCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "aicontrol",
        abstract: "Direct computer control for Claude Code - screen capture and input control",
        version: "1.0.0",
        subcommands: [
            CaptureCommand.self,
            ClickCommand.self,
            RightClickCommand.self,
            DoubleClickCommand.self,
            TypeCommand.self,
            KeyCommand.self,
            ScrollCommand.self,
            DragCommand.self,
            MoveMouseCommand.self,
            OpenAppCommand.self,
            FocusAppCommand.self,
            ShowDesktopCommand.self,
            CalibrateCommand.self,
            StatusCommand.self,
        ]
    )
}

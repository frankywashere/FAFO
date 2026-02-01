#!/usr/bin/env swift
import SwiftUI
import AppKit

/// Test app to verify TextField keyboard input works in NSHostingView
/// Run this to test the solutions before integrating into main app

// MARK: - Focusable Window
class FocusableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Test View
struct TestTextFieldView: View {
    @State private var text1 = ""
    @State private var text2 = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case text1, text2
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("TextField Focus Test")
                .font(.title)
                .padding()

            // Test 1: Standard SwiftUI TextField
            VStack(alignment: .leading, spacing: 8) {
                Text("Test 1: Standard SwiftUI TextField")
                    .font(.headline)

                TextField("Type here (SwiftUI TextField)", text: $text1)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .text1)

                Text("Input: \(text1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Test 2: Plain style TextField (like your implementation)
            VStack(alignment: .leading, spacing: 8) {
                Text("Test 2: Plain Style TextField")
                    .font(.headline)

                HStack {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.blue)

                    TextField("Type here (Plain style)", text: $text2)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .text2)
                        .frame(minHeight: 30)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(focusedField == .text2 ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                )

                Text("Input: \(text2)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions:")
                    .font(.headline)
                Text("1. Click in either text field")
                Text("2. Try typing - you should see text appear")
                Text("3. If typing doesn't work, the focus fix is needed")
            }
            .font(.caption)
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)

            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            // Auto-focus first field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .text1
            }
        }
    }
}

// MARK: - App Entry Point
@main
struct TestTextFieldApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        // Create window with FocusableWindow class
        let window = FocusableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "TextField Focus Test"
        window.contentView = NSHostingView(rootView: TestTextFieldView())
        window.center()

        // Activate and show
        app.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        print("✅ Test window opened")
        print("   If you can type in the text fields, the fix works!")
        print("   If typing doesn't work, try the NSViewRepresentable solution")

        app.run()
    }
}

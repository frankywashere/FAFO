import SwiftUI
import AppKit

/// A SwiftUI TextField wrapper that guarantees keyboard input works in NSHostingView
/// This uses NSViewRepresentable to directly access AppKit's NSTextField
struct FocusableTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void
    var isFocused: Bool

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textFieldAction(_:))
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.placeholderString = placeholder

        // Handle focus state
        if isFocused && nsView.window?.firstResponder != nsView.currentEditor() {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text = textField.stringValue
        }

        @objc func textFieldAction(_ sender: NSTextField) {
            onSubmit()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit()
                return true
            }
            return false
        }
    }
}

// MARK: - Usage Example in TaskInputView
extension TaskInputView {
    /// Alternative body using FocusableTextField
    var bodyWithFocusableTextField: some View {
        VStack(spacing: 0) {
            // Input section
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                FocusableTextField(
                    placeholder: "👉 Click here and type your task... (e.g., 'What time is it?')",
                    text: $taskInput,
                    onSubmit: submitTask,
                    isFocused: isInputFocused
                )
                .frame(minHeight: 30)

                Button(action: submitTask) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(taskInput.isEmpty ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled(taskInput.isEmpty)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isInputFocused ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    )
            )

            // Rest of the view (task history, etc.)
            // ... copy from existing TaskInputView
        }
        .onAppear {
            isInputFocused = true
        }
    }
}

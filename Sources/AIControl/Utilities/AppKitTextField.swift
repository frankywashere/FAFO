import SwiftUI
import AppKit

/// NSViewRepresentable wrapper for NSTextField that guarantees keyboard input
/// works when app is launched from terminal via `swift run`.
/// SwiftUI TextField has a known issue where keyboard events go to the parent
/// terminal process instead of the app window.
struct AppKitTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)?
    var isSecure: Bool = false
    var font: NSFont = .systemFont(ofSize: 13)

    func makeNSView(context: Context) -> NSTextField {
        let textField: NSTextField
        if isSecure {
            textField = NSSecureTextField()
        } else {
            textField = NSTextField()
        }
        textField.placeholderString = placeholder
        textField.font = font
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textFieldAction(_:))
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            _text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text = textField.stringValue
        }

        @objc func textFieldAction(_ sender: NSTextField) {
            onSubmit?()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit?()
                return true
            }
            return false
        }
    }
}

/// Styled version of AppKitTextField that looks like a rounded text input
struct StyledAppKitTextField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)?
    var isSecure: Bool = false

    var body: some View {
        AppKitTextField(
            placeholder: placeholder,
            text: $text,
            onSubmit: onSubmit,
            isSecure: isSecure
        )
        .frame(minHeight: 20)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// Styled secure field using AppKit
struct StyledAppKitSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        AppKitTextField(
            placeholder: placeholder,
            text: $text,
            isSecure: true
        )
        .frame(minHeight: 20)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

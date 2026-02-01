import SwiftUI

struct ChatView: View {
    @Binding var messages: [ChatMessage]
    @Binding var inputText: String
    let isProcessing: Bool
    let onSend: (String) -> Void
    let onSendWithScreenshot: (String) -> Void

    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if isProcessing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("AI is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .id("processing")
                        }
                    }
                    .padding(8)
                }
                .onChange(of: messages.count) { _, _ in
                    if autoScroll, let lastID = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isProcessing) { _, newValue in
                    if newValue {
                        withAnimation {
                            proxy.scrollTo("processing", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            ChatInputBar(
                text: $inputText,
                isProcessing: isProcessing,
                onSend: onSend,
                onSendWithScreenshot: onSendWithScreenshot
            )
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Role label
                HStack(spacing: 4) {
                    Image(systemName: roleIcon)
                        .font(.caption2)
                    Text(roleLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(Self.timeFormatter.string(from: message.timestamp))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                // Image indicator
                if message.hasImage {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption2)
                        Text("Screenshot attached")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }

                // Message content
                Text(message.content)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(12)
            }

            if message.role != .user { Spacer(minLength: 60) }
        }
    }

    private var roleIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "cpu"
        case .system: return "gearshape"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "AI"
        case .system: return "System"
        case .error: return "Error"
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return Color(nsColor: .controlBackgroundColor)
        case .system: return .gray.opacity(0.3)
        case .error: return .red.opacity(0.2)
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user: return .white
        default: return Color(nsColor: .labelColor)
        }
    }
}

struct ChatInputBar: View {
    @Binding var text: String
    let isProcessing: Bool
    let onSend: (String) -> Void
    let onSendWithScreenshot: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Screenshot button
            Button(action: {
                let msg = text.isEmpty ? "What do you see on the screen? Describe the current state." : text
                text = ""
                onSendWithScreenshot(msg)
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Send with screenshot")
            .disabled(isProcessing)

            // Text field - uses AppKit NSTextField to guarantee keyboard input
            // works when launched from terminal via `swift run`
            StyledAppKitTextField(
                placeholder: "Type a message...",
                text: $text,
                onSubmit: sendMessage
            )
            .opacity(isProcessing ? 0.5 : 1.0)

            // Send button (no keyboard shortcut to avoid double-fire with .onSubmit)
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(text.isEmpty || isProcessing ? .gray : .blue)
            }
            .buttonStyle(.borderless)
            .disabled(text.isEmpty || isProcessing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendMessage() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        text = ""
        onSend(trimmed)
    }
}

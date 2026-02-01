import SwiftUI

struct SessionSidebar: View {
    @ObservedObject var sessionManager: SessionManager
    let onNewSession: () -> Void

    @State private var editingSessionID: UUID?
    @State private var editName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Button(action: onNewSession) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                .help("New Session")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Session list
            if sessionManager.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(.gray)
                    Text("No sessions yet")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Button("Create Session", action: onNewSession)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .frame(maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(sessionManager.sessions) { session in
                            SessionRow(
                                session: session,
                                isActive: session.id == sessionManager.activeSessionID,
                                isEditing: editingSessionID == session.id,
                                editName: $editName,
                                onSelect: {
                                    sessionManager.switchSession(session.id)
                                },
                                onStartEditing: {
                                    editingSessionID = session.id
                                    editName = session.name
                                },
                                onFinishEditing: {
                                    if let idx = sessionManager.sessions.firstIndex(where: { $0.id == session.id }) {
                                        sessionManager.sessions[idx].name = editName
                                    }
                                    editingSessionID = nil
                                },
                                onDelete: {
                                    sessionManager.deleteSession(session.id)
                                },
                                onClearMessages: {
                                    sessionManager.clearMessages(for: session.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Recording controls
            if let activeID = sessionManager.activeSessionID {
                HStack {
                    Button(action: {
                        if sessionManager.isRecording {
                            sessionManager.stopRecording(sessionID: activeID)
                        } else {
                            sessionManager.startRecording(sessionID: activeID)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(sessionManager.isRecording ? Color.red : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(sessionManager.isRecording ? "Stop" : "Record")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Button(action: {
                        sessionManager.clearMessages(for: activeID)
                    }) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear messages")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 200, maxWidth: 260)
    }
}

struct SessionRow: View {
    let session: AISession
    let isActive: Bool
    let isEditing: Bool
    @Binding var editName: String
    let onSelect: () -> Void
    let onStartEditing: () -> Void
    let onFinishEditing: () -> Void
    let onDelete: () -> Void
    let onClearMessages: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Provider icon
            Image(systemName: providerIcon)
                .font(.system(size: 12))
                .foregroundColor(providerColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Session name", text: $editName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .onSubmit { onFinishEditing() }
                } else {
                    Text(session.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }

                Text("\(session.providerType.rawValue) - \(session.model)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !isEditing {
                Text("\(session.messages.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Rename") { onStartEditing() }
            Button("Clear Messages") { onClearMessages() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .padding(.horizontal, 4)
    }

    private var providerIcon: String {
        switch session.providerType {
        case .openai: return "brain"
        case .anthropic: return "a.circle"
        case .gemini: return "sparkles"
        case .grok: return "bolt"
        }
    }

    private var providerColor: Color {
        switch session.providerType {
        case .openai: return .green
        case .anthropic: return .orange
        case .gemini: return .blue
        case .grok: return .purple
        }
    }
}

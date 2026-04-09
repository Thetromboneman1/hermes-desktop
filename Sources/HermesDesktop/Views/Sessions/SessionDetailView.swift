import SwiftUI

struct SessionDetailView: View {
    let session: SessionSummary?
    let messages: [SessionMessage]
    let errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let session {
                    HermesSurfacePanel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(session.resolvedTitle)
                                        .font(.title2)
                                        .fontWeight(.semibold)

                                    Text(session.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }

                                Spacer(minLength: 12)

                                if let count = session.messageCount {
                                    HermesBadge(text: "\(count) messages", tint: .accentColor)
                                }
                            }

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 18) {
                                    if let startedAt = session.startedAt?.dateValue {
                                        HermesLabeledValue(
                                            label: "Started",
                                            value: DateFormatters.shortDateTimeFormatter().string(from: startedAt)
                                        )
                                    }

                                    if let lastActive = session.lastActive?.dateValue {
                                        HermesLabeledValue(
                                            label: "Last active",
                                            value: DateFormatters.shortDateTimeFormatter().string(from: lastActive)
                                        )
                                    }
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    if let startedAt = session.startedAt?.dateValue {
                                        HermesLabeledValue(
                                            label: "Started",
                                            value: DateFormatters.shortDateTimeFormatter().string(from: startedAt)
                                        )
                                    }

                                    if let lastActive = session.lastActive?.dateValue {
                                        HermesLabeledValue(
                                            label: "Last active",
                                            value: DateFormatters.shortDateTimeFormatter().string(from: lastActive)
                                        )
                                    }
                                }
                            }
                        }
                    }

                    if let errorMessage {
                        HermesSurfacePanel {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }

                    if messages.isEmpty {
                        HermesSurfacePanel {
                            ContentUnavailableView(
                                "No transcript entries",
                                systemImage: "text.bubble",
                                description: Text("This session has no readable message rows yet.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 280)
                        }
                    } else {
                        HermesSurfacePanel(
                            title: "Transcript",
                            subtitle: "Messages are shown in the order Hermes stored them for this session."
                        ) {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(messages) { message in
                                    MessageCard(message: message)
                                }
                            }
                        }
                    }
                } else {
                    HermesSurfacePanel {
                        ContentUnavailableView(
                            "Select a session",
                            systemImage: "rectangle.stack.person.crop",
                            description: Text("Choose a Hermes session from the active host to inspect its transcript.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
    }
}

private struct MessageCard: View {
    let message: SessionMessage

    var body: some View {
        HermesInsetSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    HermesBadge(
                        text: displayRole,
                        tint: roleTint,
                        isMonospaced: false
                    )

                    Spacer()

                    if let timestamp = message.timestamp?.dateValue {
                        Text(DateFormatters.shortDateTimeFormatter().string(from: timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let content = message.content, !content.isEmpty {
                    Text(content)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No text payload")
                        .foregroundStyle(.secondary)
                        .italic()
                }

                if let metadata = message.metadata, !metadata.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metadata")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(metadata.keys.sorted(), id: \.self) { key in
                            if let value = metadata[key] {
                                HermesInsetSurface {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(key)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)

                                        Text(value.displayString)
                                            .font(.caption.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var displayRole: String {
        let role = (message.role ?? "event").replacingOccurrences(of: "_", with: " ")
        return role.capitalized
    }

    private var roleTint: Color {
        switch (message.role ?? "").lowercased() {
        case "assistant":
            return .blue
        case "user":
            return .green
        case "system":
            return .orange
        default:
            return .secondary
        }
    }
}

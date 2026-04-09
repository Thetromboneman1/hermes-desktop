import SwiftUI

struct SessionDetailView: View {
    let session: SessionSummary?
    let messages: [SessionMessage]
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let session {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.resolvedTitle)
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(session.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if messages.isEmpty {
                    ContentUnavailableView(
                        "No transcript entries",
                        systemImage: "text.bubble",
                        description: Text("This session has no readable message rows yet.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a session",
                    systemImage: "rectangle.stack.person.crop",
                    description: Text("Choose a Hermes session from the active host to inspect its transcript.")
                )
            }
        }
        .padding(24)
    }
}

private struct MessageBubble: View {
    let message: SessionMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.role ?? "event")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

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
            } else {
                Text("No text payload")
                    .foregroundStyle(.secondary)
                    .italic()
            }

            if let metadata = message.metadata, !metadata.isEmpty {
                Divider()
                ForEach(metadata.keys.sorted(), id: \.self) { key in
                    if let value = metadata[key] {
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
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

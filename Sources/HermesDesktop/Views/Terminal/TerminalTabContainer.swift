import SwiftUI

struct TerminalTabContainer: View {
    @ObservedObject var session: TerminalSession
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.connection.displayDestination)
                    .font(.headline)

                if let currentDirectory = session.currentDirectory {
                    Text(currentDirectory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let exitCode = session.exitCode {
                    Text(exitCode == 0 ? "Shell exited" : "Connection ended (\(exitCode))")
                        .font(.caption)
                        .foregroundStyle(exitCode == 0 ? Color.secondary : Color.orange)

                    Button("Reconnect") {
                        session.requestReconnect()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))

            SwiftTermTerminalView(session: session, isActive: isActive)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

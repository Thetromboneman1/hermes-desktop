import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Remote Overview")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        Text("Live discovery is always resolved from the remote HOME over SSH.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Reconnect") {
                        appState.reconnectActiveConnection()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let activeConnection = appState.activeConnection {
                    GroupBox("Connection") {
                        LabeledContent("Host", value: activeConnection.label)
                        LabeledContent("SSH target", value: activeConnection.displayDestination)
                    }
                }

                if let overview = appState.overview {
                    GroupBox("Resolved Paths") {
                        LabeledContent("Remote HOME", value: overview.remoteHome)
                        LabeledContent("Hermes root", value: overview.hermesHome)
                        LabeledContent("MEMORY.md", value: overview.paths.memory)
                        LabeledContent("USER.md", value: overview.paths.user)
                        LabeledContent("Session artifacts", value: overview.paths.sessionsDir)
                    }

                    GroupBox("Availability") {
                        StateRow(label: "MEMORY.md", isPresent: overview.exists.memory)
                        StateRow(label: "USER.md", isPresent: overview.exists.user)
                        StateRow(label: "Session artifacts", isPresent: overview.exists.sessionsDir)
                        StateRow(label: "SQLite store", isPresent: overview.sessionStore != nil)
                    }

                    if let sessionStore = overview.sessionStore {
                        GroupBox("Session Store") {
                            LabeledContent("Kind", value: sessionStore.kind)
                            LabeledContent("Path", value: sessionStore.path)
                            if let sessionTable = sessionStore.sessionTable {
                                LabeledContent("Sessions table", value: sessionTable)
                            }
                            if let messageTable = sessionStore.messageTable {
                                LabeledContent("Messages table", value: messageTable)
                            }
                        }
                    } else if overview.exists.sessionsDir {
                        GroupBox("Session Store") {
                            Text("No SQLite session store was detected under ~/.hermes. The session browser will fall back to JSONL transcript artifacts under ~/.hermes/sessions when available.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Button("Open Files") {
                            appState.requestSectionSelection(.files)
                        }
                        Button("Open Sessions") {
                            appState.requestSectionSelection(.sessions)
                        }
                        Button("Open Terminal") {
                            appState.requestSectionSelection(.terminal)
                        }
                    }
                } else if let overviewError = appState.overviewError {
                    ContentUnavailableView(
                        "Discovery failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(overviewError)
                    )
                } else {
                    ProgressView("Discovering Hermes data on the active SSH target…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding(24)
        }
        .task(id: appState.activeConnectionID) {
            if appState.overview == nil {
                await appState.refreshOverview()
            }
        }
    }
}

private struct StateRow: View {
    let label: String
    let isPresent: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: isPresent ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isPresent ? .green : .red)
        }
        .padding(.vertical, 2)
    }
}

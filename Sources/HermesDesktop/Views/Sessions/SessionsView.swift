import SwiftUI

struct SessionsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Sessions")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Refresh") {
                        Task { await appState.loadSessions(reset: true) }
                    }
                }

                if appState.isLoadingSessions && appState.sessions.isEmpty {
                    ProgressView("Loading sessions…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = appState.sessionsError, appState.sessions.isEmpty {
                    ContentUnavailableView(
                        "Unable to load sessions",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if appState.sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions found",
                        systemImage: "tray",
                        description: Text("No readable Hermes sessions were discovered yet for this SSH target.")
                    )
                } else {
                    List(selection: selectionBinding) {
                        ForEach(appState.sessions) { session in
                            SessionRow(session: session)
                                .tag(session.id)
                        }

                        if appState.hasMoreSessions {
                            HStack {
                                Spacer()
                                Button("Load More") {
                                    Task { await appState.loadSessions(reset: false) }
                                }
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 330, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)

            SessionDetailView(
                session: selectedSession,
                messages: appState.sessionMessages,
                errorMessage: appState.sessionsError
            )
            .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: appState.activeConnectionID) {
            if appState.sessions.isEmpty {
                await appState.loadSessions(reset: true)
            }
        }
    }

    private var selectedSession: SessionSummary? {
        guard let selectedSessionID = appState.selectedSessionID else { return nil }
        return appState.sessions.first(where: { $0.id == selectedSessionID })
    }

    private var selectionBinding: Binding<String?> {
        Binding {
            appState.selectedSessionID
        } set: { newValue in
            guard let newValue else { return }
            Task {
                await appState.loadSessionDetail(sessionID: newValue)
            }
        }
    }
}

private struct SessionRow: View {
    let session: SessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.resolvedTitle)
                .font(.headline)
            Text(session.id)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let preview = session.preview, !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if let count = session.messageCount {
                    Label("\(count)", systemImage: "message")
                        .font(.caption)
                }

                if let lastActive = session.lastActive?.dateValue {
                    Text(DateFormatters.relativeFormatter().localizedString(for: lastActive, relativeTo: .now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

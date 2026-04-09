import SwiftUI

struct TerminalWorkspaceView: View {
    @ObservedObject var workspace: TerminalWorkspaceStore
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(workspace.tabs) { tab in
                    TerminalTabChip(
                        title: tab.session.terminalTitle,
                        isSelected: workspace.selectedTabID == tab.id,
                        onSelect: { workspace.selectedTabID = tab.id },
                        onClose: { workspace.closeTab(tab) }
                    )
                }

                if let activeConnection = appState.activeConnection {
                    Button {
                        workspace.addTab(for: activeConnection)
                    } label: {
                        Label("New Tab", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.thinMaterial)

            if !workspace.tabs.isEmpty {
                ZStack {
                    ForEach(workspace.tabs) { tab in
                        let isActiveTerminal =
                            appState.selectedSection == .terminal &&
                            workspace.selectedTabID == tab.id

                        TerminalTabContainer(session: tab.session, isActive: isActiveTerminal)
                            .opacity(isActiveTerminal ? 1 : 0)
                            .allowsHitTesting(isActiveTerminal)
                            .zIndex(isActiveTerminal ? 1 : 0)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No terminal tab",
                    systemImage: "terminal",
                    description: Text("Create a tab to start a real SSH shell for the active host.")
                )
            }
        }
        .task(id: appState.activeConnectionID) {
            if appState.selectedSection == .terminal {
                appState.ensureTerminalSession()
            }
        }
        .onChange(of: appState.selectedSection) { _, newValue in
            if newValue == .terminal {
                appState.ensureTerminalSession()
            }
        }
    }
}

private struct TerminalTabChip: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                Text(title)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Close tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
        .clipShape(Capsule())
    }
}

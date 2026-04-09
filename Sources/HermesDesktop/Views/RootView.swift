import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(selection: sectionSelection) {
                if let activeConnection = appState.activeConnection {
                    Section("Active Connection") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activeConnection.label)
                                .font(.headline)
                            Text(activeConnection.displayDestination)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Workspace") {
                    ForEach(availableSections) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            detailView
        }
        .overlay(alignment: .bottom) {
            if let statusMessage = appState.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding()
            }
        }
        .alert(item: $appState.activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Discard unsaved changes?", isPresented: $appState.showDiscardChangesAlert) {
            Button("Discard", role: .destructive) {
                appState.discardChangesAndContinue()
            }
            Button("Stay", role: .cancel) {
                appState.stayOnCurrentSection()
            }
        } message: {
            Text("MEMORY.md or USER.md has unsaved edits.")
        }
    }

    private var availableSections: [AppSection] {
        if appState.activeConnection == nil {
            return [.connections]
        }
        return [.connections, .overview, .files, .sessions, .terminal]
    }

    private var sectionSelection: Binding<AppSection?> {
        Binding {
            appState.selectedSection
        } set: { newValue in
            guard let newValue else { return }
            appState.requestSectionSelection(newValue)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        ZStack(alignment: .topLeading) {
            if appState.activeConnection != nil {
                TerminalWorkspaceView(workspace: appState.terminalWorkspace)
                    .opacity(appState.selectedSection == .terminal ? 1 : 0)
                    .allowsHitTesting(appState.selectedSection == .terminal)
                    .zIndex(appState.selectedSection == .terminal ? 1 : 0)
            }

            switch appState.selectedSection {
            case .connections:
                ConnectionsView()
            case .overview:
                OverviewView()
            case .files:
                FilesView()
            case .sessions:
                SessionsView()
            case .terminal:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

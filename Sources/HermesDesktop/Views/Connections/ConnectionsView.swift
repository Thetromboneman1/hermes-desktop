import SwiftUI

struct ConnectionsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var editingConnection = ConnectionProfile()
    @State private var isPresentingEditor = false
    @State private var editingExistingConnection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hermes Hosts")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text("Alias-first SSH profiles for any Hermes host: Raspberry Pi, another Mac, a VPS, or this Mac via localhost.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    editingConnection = ConnectionProfile()
                    editingExistingConnection = false
                    isPresentingEditor = true
                } label: {
                    Label("New Host", systemImage: "plus")
                }
            }

            if appState.connectionStore.connections.isEmpty {
                ContentUnavailableView(
                    "No hosts yet",
                    systemImage: "network.slash",
                    description: Text("Create an SSH profile for a Raspberry Pi, another Mac, a VPS, or this Mac via localhost.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.connectionStore.connections) { connection in
                        ConnectionRow(
                            connection: connection,
                            isActive: appState.activeConnectionID == connection.id,
                            onConnect: { appState.connect(to: connection) },
                            onTest: { appState.testConnection(connection) },
                            onEdit: {
                                editingConnection = connection
                                editingExistingConnection = true
                                isPresentingEditor = true
                            },
                            onDelete: { appState.deleteConnection(connection) }
                        )
                    }
                }
                .listStyle(.inset)
            }

            GroupBox("Target Tips") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended: use an SSH alias from `~/.ssh/config` when possible.")
                    TipRow(label: "Alias", value: "hermes-home")
                    TipRow(label: "Hostname", value: "mac-studio.local")
                    TipRow(label: "LAN or public IP", value: "192.168.1.24 or 203.0.113.10")
                    TipRow(label: "Same Mac", value: "localhost or a local SSH alias")
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .sheet(isPresented: $isPresentingEditor) {
            ConnectionEditorSheet(
                connection: editingConnection,
                isEditing: editingExistingConnection
            ) { updatedConnection in
                appState.connectionStore.upsert(updatedConnection)
            }
        }
    }
}

private struct TipRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .fontWeight(.semibold)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

private struct ConnectionRow: View {
    let connection: ConnectionProfile
    let isActive: Bool
    let onConnect: () -> Void
    let onTest: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(connection.label)
                            .font(.headline)
                        if isActive {
                            Text("ACTIVE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                    }

                    Text(connection.displayDestination)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack {
                Button("Connect", action: onConnect)
                    .buttonStyle(.borderedProminent)
                Button("Test", action: onTest)
                Button("Edit", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

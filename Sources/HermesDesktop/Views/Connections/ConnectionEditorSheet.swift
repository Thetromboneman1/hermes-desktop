import SwiftUI

struct ConnectionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable {
        case label
        case alias
        case host
        case user
        case port
    }

    @State private var draft: ConnectionProfile
    @State private var portText: String
    @FocusState private var focusedField: Field?
    let isEditing: Bool
    let onSave: (ConnectionProfile) -> Void

    init(connection: ConnectionProfile, isEditing: Bool, onSave: @escaping (ConnectionProfile) -> Void) {
        _draft = State(initialValue: connection)
        _portText = State(initialValue: connection.sshPort.map(String.init) ?? "")
        self.isEditing = isEditing
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hermes Host") {
                    TextField("Label", text: $draft.label, prompt: Text("Home Pi, Studio Mac, Prod VPS"))
                        .focused($focusedField, equals: .label)
                        .textFieldStyle(.roundedBorder)
                    TextField("SSH alias (recommended)", text: $draft.sshAlias, prompt: Text("hermes-home"))
                        .focused($focusedField, equals: .alias)
                        .textFieldStyle(.roundedBorder)
                    TextField("Host or IP", text: $draft.sshHost, prompt: Text("mac-studio.local, 203.0.113.10, localhost"))
                        .focused($focusedField, equals: .host)
                        .textFieldStyle(.roundedBorder)
                    TextField("User (optional override)", text: $draft.sshUser, prompt: Text("alex"))
                        .focused($focusedField, equals: .user)
                        .textFieldStyle(.roundedBorder)
                    TextField("Port (optional override)", text: $portText, prompt: Text("22"))
                        .focused($focusedField, equals: .port)
                        .textFieldStyle(.roundedBorder)
                }

                Section("How Hermes Desktop Connects") {
                    Text("Use an SSH alias when possible. Hostnames, local `.local` names, LAN IPs, public IPs, VPS names, and `localhost` are all valid SSH targets.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("If Hermes runs on this same Mac, keep the SSH-only model: connect using `localhost`, the local hostname, or a local SSH alias.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if draft.trimmedAlias != nil && draft.trimmedHost != nil {
                        Text("SSH alias takes priority for the target. The Host value is kept in the profile but ignored while the alias is present.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } else {
                        Text("If an alias is present, leave Host blank to keep the system SSH config as the source of truth. User and Port can still be used as explicit overrides when needed.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Examples") {
                    ExampleValueRow(label: "Raspberry Pi", value: "Alias `hermes-home` or host `raspberrypi.local`")
                    ExampleValueRow(label: "Remote Mac", value: "Host `mac-studio.local`")
                    ExampleValueRow(label: "VPS", value: "Host `vps.example.com` or `203.0.113.10`")
                    ExampleValueRow(label: "Same Mac", value: "Host `localhost` or a local SSH alias")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Host" : "New Host")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedDraft = draft
                        updatedDraft.sshPort = parsedPort
                        onSave(updatedDraft)
                        dismiss()
                    }
                    .disabled(!isDraftValid)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 320)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                focusedField = .label
            }
        }
    }

    private var parsedPort: Int? {
        let trimmed = portText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    private var isDraftValid: Bool {
        let hasValidPort = portText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedPort != nil
        var candidate = draft
        candidate.sshPort = parsedPort
        return hasValidPort && candidate.isValid
    }
}

private struct ExampleValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

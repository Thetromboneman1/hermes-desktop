import Foundation

final class TerminalTabModel: ObservableObject, Identifiable {
    let id = UUID()
    let connectionID: UUID
    let session: TerminalSession
    @Published var title: String

    init(title: String, connectionID: UUID, session: TerminalSession) {
        self.title = title
        self.connectionID = connectionID
        self.session = session
    }
}

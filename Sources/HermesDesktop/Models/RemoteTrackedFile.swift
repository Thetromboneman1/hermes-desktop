import Foundation

enum RemoteTrackedFile: String, CaseIterable, Identifiable {
    case memory
    case user

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memory:
            "MEMORY.md"
        case .user:
            "USER.md"
        }
    }

    var fileName: String { title }

    var remoteTildePath: String {
        switch self {
        case .memory:
            "~/.hermes/memories/MEMORY.md"
        case .user:
            "~/.hermes/memories/USER.md"
        }
    }
}

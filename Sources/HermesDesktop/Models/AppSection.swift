import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case connections
    case overview
    case files
    case sessions
    case terminal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connections:
            "Connections"
        case .overview:
            "Overview"
        case .files:
            "Files"
        case .sessions:
            "Sessions"
        case .terminal:
            "Terminal"
        }
    }

    var systemImage: String {
        switch self {
        case .connections:
            "network"
        case .overview:
            "waveform.path.ecg"
        case .files:
            "doc.text"
        case .sessions:
            "clock.arrow.circlepath"
        case .terminal:
            "terminal"
        }
    }
}

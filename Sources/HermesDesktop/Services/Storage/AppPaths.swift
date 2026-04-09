import Foundation

struct AppPaths {
    let fileManager: FileManager
    let applicationSupportURL: URL
    let connectionsURL: URL
    let preferencesURL: URL
    let controlSocketDirectoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let baseSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let appSupport = baseSupport.appendingPathComponent("HermesDesktop", isDirectory: true)

        let controlDirectory = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("hermes-desktop-control", isDirectory: true)

        self.applicationSupportURL = appSupport
        self.connectionsURL = appSupport.appendingPathComponent("connections.json")
        self.preferencesURL = appSupport.appendingPathComponent("preferences.json")
        self.controlSocketDirectoryURL = controlDirectory

        createIfNeeded(at: appSupport)
        createIfNeeded(at: controlDirectory)
    }

    func controlPath(for connection: ConnectionProfile) -> String {
        controlSocketDirectoryURL
            .appendingPathComponent(connection.id.uuidString.replacingOccurrences(of: "-", with: ""))
            .path
    }

    private func createIfNeeded(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
}

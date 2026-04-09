import AppKit
import SwiftUI

@main
struct HermesDesktopApp: App {
    @NSApplicationDelegateAdaptor(HermesApplicationDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("Hermes Desktop") {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1180, minHeight: 760)
                .background {
                    MainWindowAccessor(
                        title: "Hermes Desktop",
                        minSize: NSSize(width: 1180, height: 760)
                    )
                }
        }
        .defaultSize(width: 1360, height: 860)
    }
}

import AppKit
import SwiftUI

@MainActor
final class HermesApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}

@MainActor
struct MainWindowAccessor: NSViewRepresentable {
    let title: String
    let minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWindowIfNeeded(for: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindowIfNeeded(for: nsView, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configureWindowIfNeeded(for view: NSView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            coordinator.configure(window: window, title: title, minSize: minSize)
        }
    }

    @MainActor
    final class Coordinator {
        private weak var configuredWindow: NSWindow?

        func configure(window: NSWindow, title: String, minSize: NSSize) {
            guard configuredWindow !== window else { return }
            configuredWindow = window

            window.title = title
            window.minSize = minSize
            window.styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable])
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.titlebarAppearsTransparent = false
            window.isMovableByWindowBackground = false
            window.toolbarStyle = .unified

            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

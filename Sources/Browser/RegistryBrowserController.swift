import AppKit
import SwiftUI


enum AppCommand: Equatable {
    case openRegistry
    case overlay(String)
}


enum AppMessageRouter {
    static func route(_ message: String) -> AppCommand {
        message == "registry-open" ? .openRegistry : .overlay(message)
    }
}


enum BrowserOpenAction: Equatable {
    case create
    case raiseExisting
}


struct BrowserWindowLogic {
    private(set) var isOpen = false

    mutating func open() -> BrowserOpenAction {
        if isOpen { return .raiseExisting }
        isOpen = true
        return .create
    }

    mutating func closed() {
        isOpen = false
    }
}


@available(macOS 14, *)
final class RegistryBrowserController: NSObject, NSWindowDelegate {
    private let registryResult: Result<KeybindingRegistry, Error>
    private var logic = BrowserWindowLogic()
    private var window: NSWindow?

    init(registryResult: Result<KeybindingRegistry, Error>) {
        self.registryResult = registryResult
    }

    func open() {
        switch logic.open() {
        case .create:
            let content = RegistryBrowserView(registryResult: registryResult)
            let hostView = NSHostingView(rootView: content)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Keybinding Registry"
            window.minSize = NSSize(width: 900, height: 560)
            window.contentView = hostView
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        case .raiseExisting:
            break
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        logic.closed()
    }
}

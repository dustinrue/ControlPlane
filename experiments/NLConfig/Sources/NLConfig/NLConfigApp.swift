import SwiftUI
import AppKit

// When launched via `swift run` / `make run` the process starts as a
// command-line tool subprocess of the terminal. Without explicit setup the
// window appears but the terminal keeps keyboard focus.
// Fixes:
//   1. setActivationPolicy(.regular) — promotes the process to a foreground
//      app so it gets a Dock tile and can own keyboard focus.
//   2. activate(ignoringOtherApps:) in applicationDidFinishLaunching — called
//      at the right moment after the run loop is ready.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@main
struct NLConfigApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 700)
    }
}

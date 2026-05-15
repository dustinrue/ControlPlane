import SwiftUI
import AppKit

@main
struct NLConfigApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // When launched from the terminal the window opens but the
                    // terminal retains keyboard focus. Force-activate so the app
                    // window receives keystrokes immediately.
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 700)
    }
}

import AppKit

// Disable stdout buffering so log lines appear immediately in log files.
setbuf(stdout, nil)

let app = NSApplication.shared
// AppDelegate is @MainActor; main.swift runs on the main thread at startup,
// so MainActor.assumeIsolated satisfies the isolation requirement without
// changing runtime behaviour.
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()

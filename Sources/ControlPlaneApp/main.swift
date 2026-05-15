import AppKit

// Disable stdout buffering so log lines appear immediately in log files.
setbuf(stdout, nil)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

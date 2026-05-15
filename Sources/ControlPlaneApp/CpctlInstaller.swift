import Foundation

/// Checks whether cpctl is installed and, if not, installs it from the app bundle.
///
/// Called once at app launch. If the tool is already present at the install
/// path we leave it alone — the user may have a newer version or a custom build.
/// If it's missing we copy the bundled binary, codesign it, and notify the user.
enum CpctlInstaller {

    // Install into ~/.local/bin — writable without elevated privileges and
    // follows the XDG convention that most developer shell configs include.
    private static let installDir  = URL(fileURLWithPath: NSHomeDirectory())
                                         .appendingPathComponent(".local/bin").path
    private static let installPath = (installDir as NSString)
                                         .appendingPathComponent("cpctl")

    static func installIfNeeded() {
        if FileManager.default.fileExists(atPath: installPath) {
            log("cpctl already installed at \(installPath)")
            return
        }

        // Bundle.main.path(forAuxiliaryExecutable:) resolves Contents/MacOS/<name>
        guard let bundled = Bundle.main.path(forAuxiliaryExecutable: "cpctl") else {
            log("cpctl not found in app bundle — skipping auto-install")
            return
        }

        do {
            try FileManager.default.createDirectory(
                atPath: installDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try FileManager.default.copyItem(atPath: bundled, toPath: installPath)
            codesign(path: installPath)
            log("cpctl installed to \(installPath)")
            Notifier.send(
                title: "cpctl installed",
                body: "Command-line tool is available at \(installPath)"
            )
        } catch {
            log("cpctl auto-install failed: \(error)")
        }
    }

    // MARK: - Private

    private static func codesign(path: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        proc.arguments = ["--force", "--sign", "-", path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError  = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            log("cpctl codesign exited \(proc.terminationStatus) — binary may still work")
        }
    }
}

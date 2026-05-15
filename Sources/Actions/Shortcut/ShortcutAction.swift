import Foundation
import ControlPlaneSDK

/// Action plugin that runs a macOS Shortcut by its stable UUID.
///
/// Config keys:
///   - `shortcutID`   (required) — the UUID of the shortcut, e.g. "A1B2C3D4-..."
///   - `shortcutName` (optional) — human-readable name for display purposes only
///
/// The UUID is used to execute the shortcut so renaming a shortcut in the
/// Shortcuts app does not break the action.
public final class ShortcutAction: BaseAction {

    // MARK: - Config key constants

    public static let keyShortcutID   = "shortcutID"
    public static let keyShortcutName = "shortcutName"

    // MARK: - ControlPlanePlugin

    public override var pluginIdentifier: String  { "com.controlplane.action.shortcut" }
    public override var pluginDisplayName: String { "Run Shortcut" }
    public override var pluginVersion: String     { "1.0.0" }

    // MARK: - ActionPlugin

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let shortcutID = config[ShortcutAction.keyShortcutID], !shortcutID.isEmpty else {
            throw ShortcutActionError.missingShortcutID
        }

        let displayName = config[ShortcutAction.keyShortcutName] ?? shortcutID
        try await runShortcut(id: shortcutID, displayName: displayName)
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: ShortcutAction.keyShortcutID,
                label: "Shortcut",
                description: "The UUID of the macOS shortcut to run (use `cpctl shortcuts list` to find UUIDs).",
                required: true
            ),
            ActionConfigDescriptor(
                key: ShortcutAction.keyShortcutName,
                label: "Shortcut Name",
                description: "Display name shown in logs and the UI. Does not affect which shortcut runs.",
                required: false
            ),
        ]
    }

    // MARK: - Applicability

    public override class func isApplicable() -> Bool {
        FileManager.default.fileExists(atPath: "/usr/bin/shortcuts")
    }

    // MARK: - Private

    private func runShortcut(id: String, displayName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", id]

            // Swallow stdout/stderr — the Shortcuts app owns its own UI.
            process.standardOutput = FileHandle.nullDevice
            process.standardError  = FileHandle.nullDevice

            process.terminationHandler = { p in
                let status = p.terminationStatus
                if status == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ShortcutActionError.shortcutFailed(id: id, status: status))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Errors

public enum ShortcutActionError: LocalizedError {
    case missingShortcutID
    case shortcutFailed(id: String, status: Int32)

    public var errorDescription: String? {
        switch self {
        case .missingShortcutID:
            return "ShortcutAction: no shortcutID in config"
        case .shortcutFailed(let id, let status):
            return "ShortcutAction: shortcut '\(id)' exited with status \(status)"
        }
    }
}

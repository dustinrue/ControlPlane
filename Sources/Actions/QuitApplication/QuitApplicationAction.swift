import Foundation
import AppKit
import ControlPlaneSDK

public final class QuitApplicationAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.quitapplication" }
    public override var pluginDisplayName: String { "Quit Application" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let bundleID = config["bundleIdentifier"], !bundleID.isEmpty else {
            throw QuitApplicationActionError.missingBundleIdentifier
        }
        let force = config["force"] == "true"
        await MainActor.run {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            for app in apps {
                if force {
                    app.forceTerminate()
                } else {
                    app.terminate()
                }
            }
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "bundleIdentifier",
                label: "Bundle Identifier",
                description: "Bundle identifier of the application to quit, e.g. com.apple.Safari.",
                required: true
            ),
            ActionConfigDescriptor(
                key: "force",
                label: "Force Quit",
                description: "Set to 'true' to force-terminate instead of a graceful quit.",
                required: false
            ),
        ]
    }
}

public enum QuitApplicationActionError: LocalizedError {
    case missingBundleIdentifier

    public var errorDescription: String? {
        switch self {
        case .missingBundleIdentifier:
            return "QuitApplicationAction: no bundleIdentifier in config"
        }
    }
}

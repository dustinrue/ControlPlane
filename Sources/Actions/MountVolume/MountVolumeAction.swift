import Foundation
import AppKit
import ControlPlaneSDK

public final class MountVolumeAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.mountvolume" }
    public override var pluginDisplayName: String { "Mount Volume" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let serverURL = config["serverURL"], !serverURL.isEmpty else {
            throw MountVolumeActionError.missingServerURL
        }
        guard let url = URL(string: serverURL) else {
            throw MountVolumeActionError.invalidServerURL(string: serverURL)
        }
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "serverURL",
                label: "Server URL",
                description: "URL of the volume to mount, e.g. smb://server/share.",
                required: true
            ),
        ]
    }
}

public enum MountVolumeActionError: LocalizedError {
    case missingServerURL
    case invalidServerURL(string: String)

    public var errorDescription: String? {
        switch self {
        case .missingServerURL:
            return "MountVolumeAction: no serverURL in config"
        case .invalidServerURL(let s):
            return "MountVolumeAction: invalid URL '\(s)'"
        }
    }
}

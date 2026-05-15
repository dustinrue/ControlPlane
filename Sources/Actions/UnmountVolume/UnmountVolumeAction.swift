import Foundation
import AppKit
import ControlPlaneSDK

public final class UnmountVolumeAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.unmountvolume" }
    public override var pluginDisplayName: String { "Unmount Volume" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let path = config["volumePath"], !path.isEmpty else {
            throw UnmountVolumeActionError.missingVolumePath
        }
        let success = await MainActor.run {
            NSWorkspace.shared.unmountAndEjectDevice(atPath: path)
        }
        if !success {
            throw UnmountVolumeActionError.unmountFailed(path: path)
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "volumePath",
                label: "Volume Path",
                description: "Mount point of the volume to eject, e.g. /Volumes/MyDrive.",
                required: true
            ),
        ]
    }
}

public enum UnmountVolumeActionError: LocalizedError {
    case missingVolumePath
    case unmountFailed(path: String)

    public var errorDescription: String? {
        switch self {
        case .missingVolumePath:
            return "UnmountVolumeAction: no volumePath in config"
        case .unmountFailed(let path):
            return "UnmountVolumeAction: failed to unmount \(path)"
        }
    }
}

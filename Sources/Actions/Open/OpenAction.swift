import Foundation
import AppKit
import ControlPlaneSDK

public final class OpenAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.open" }
    public override var pluginDisplayName: String { "Open File or Application" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let path = config["path"], !path.isEmpty else {
            throw OpenActionError.missingPath
        }
        await MainActor.run {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "path",
                label: "Path",
                description: "Absolute path to the file or application bundle to open.",
                required: true
            ),
        ]
    }
}

public enum OpenActionError: LocalizedError {
    case missingPath

    public var errorDescription: String? {
        switch self {
        case .missingPath:
            return "OpenAction: no path in config"
        }
    }
}

import Foundation
import AppKit
import ControlPlaneSDK

public final class OpenAndHideAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.openandhide" }
    public override var pluginDisplayName: String { "Open and Hide Application" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let path = config["path"], !path.isEmpty else {
            throw OpenAndHideActionError.missingPath
        }
        let url = URL(fileURLWithPath: path)
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {
            let resolvedPath = url.standardized.path
            for app in NSWorkspace.shared.runningApplications {
                if let bundleURL = app.bundleURL {
                    if bundleURL.standardized.path == resolvedPath {
                        app.hide()
                    }
                }
            }
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "path",
                label: "Application Path",
                description: "Absolute path to the application bundle to open and hide.",
                required: true
            ),
        ]
    }
}

public enum OpenAndHideActionError: LocalizedError {
    case missingPath

    public var errorDescription: String? {
        switch self {
        case .missingPath:
            return "OpenAndHideAction: no path in config"
        }
    }
}

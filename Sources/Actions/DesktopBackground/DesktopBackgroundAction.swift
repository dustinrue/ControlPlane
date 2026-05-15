import Foundation
import AppKit
import ControlPlaneSDK

public final class DesktopBackgroundAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.desktopbackground" }
    public override var pluginDisplayName: String { "Set Desktop Background" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let imagePath = config["imagePath"], !imagePath.isEmpty else {
            throw DesktopBackgroundActionError.missingImagePath
        }
        let screenTarget = config["screen"] ?? "all"
        let url = URL(fileURLWithPath: imagePath)

        try await MainActor.run {
            let screens: [NSScreen]
            if screenTarget == "main", let main = NSScreen.main {
                screens = [main]
            } else {
                screens = NSScreen.screens
            }
            for screen in screens {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "imagePath",
                label: "Image Path",
                description: "Absolute path to the image file to use as the desktop background.",
                required: true
            ),
            ActionConfigDescriptor(
                key: "screen",
                label: "Screen",
                description: "'all' to set on every display (default) or 'main' for the main display only.",
                required: false
            ),
        ]
    }
}

public enum DesktopBackgroundActionError: LocalizedError {
    case missingImagePath

    public var errorDescription: String? {
        switch self {
        case .missingImagePath:
            return "DesktopBackgroundAction: no imagePath in config"
        }
    }
}

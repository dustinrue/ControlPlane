import Foundation
import AppKit
import ControlPlaneSDK

public final class OpenURLAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.openurl" }
    public override var pluginDisplayName: String { "Open URL" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let urlString = config["url"], !urlString.isEmpty else {
            throw OpenURLActionError.missingURL
        }
        guard let url = URL(string: urlString) else {
            throw OpenURLActionError.malformedURL(string: urlString)
        }
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "url",
                label: "URL",
                description: "URL to open, e.g. https://example.com or myapp://action.",
                required: true
            ),
        ]
    }
}

public enum OpenURLActionError: LocalizedError {
    case missingURL
    case malformedURL(string: String)

    public var errorDescription: String? {
        switch self {
        case .missingURL:
            return "OpenURLAction: no url in config"
        case .malformedURL(let s):
            return "OpenURLAction: malformed URL '\(s)'"
        }
    }
}

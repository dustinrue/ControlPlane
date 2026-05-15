import Foundation
import ControlPlaneSDK

public final class NetworkLocationAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.networklocation" }
    public override var pluginDisplayName: String { "Switch Network Location" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let name = config["locationName"], !name.isEmpty else {
            throw NetworkLocationActionError.missingLocationName
        }
        try await runProcess(executable: "/usr/sbin/networksetup", arguments: ["-switchtolocation", name])
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "locationName",
                label: "Location Name",
                description: "Name of the macOS network location to switch to.",
                required: true
            ),
        ]
    }
}

public enum NetworkLocationActionError: LocalizedError {
    case missingLocationName

    public var errorDescription: String? {
        switch self {
        case .missingLocationName:
            return "NetworkLocationAction: no locationName in config"
        }
    }
}

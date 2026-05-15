import Foundation
import CoreWLAN
import ControlPlaneSDK

public final class ToggleWiFiAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.togglewifi" }
    public override var pluginDisplayName: String { "Toggle WiFi" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let state = config["state"], !state.isEmpty else {
            throw ToggleWiFiActionError.missingState
        }
        let on: Bool
        switch state.lowercased() {
        case "on":  on = true
        case "off": on = false
        default:
            throw ToggleWiFiActionError.invalidState(state: state)
        }
        guard let iface = CWWiFiClient.shared().interface() else {
            throw ToggleWiFiActionError.noInterface
        }
        try iface.setPower(on)
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "state",
                label: "State",
                description: "'on' to enable WiFi, 'off' to disable.",
                required: true
            ),
        ]
    }

    public override class func isApplicable() -> Bool {
        CWWiFiClient.shared().interface() != nil
    }
}

public enum ToggleWiFiActionError: LocalizedError {
    case missingState
    case invalidState(state: String)
    case noInterface

    public var errorDescription: String? {
        switch self {
        case .missingState:
            return "ToggleWiFiAction: no state in config"
        case .invalidState(let s):
            return "ToggleWiFiAction: invalid state '\(s)'; expected 'on' or 'off'"
        case .noInterface:
            return "ToggleWiFiAction: no WiFi interface found"
        }
    }
}

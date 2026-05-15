import Foundation
import IOKit
import IOKit.pwr_mgt
import ControlPlaneSDK

public final class PreventDisplaySleepAction: BaseAction {

    private static var assertionID: IOPMAssertionID = 0

    public override var pluginIdentifier: String  { "com.controlplane.action.preventdisplaysleep" }
    public override var pluginDisplayName: String { "Prevent Display Sleep" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let state = config["state"], !state.isEmpty else {
            throw SleepPreventionError.missingState
        }
        switch state.lowercased() {
        case "on":
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "ControlPlane: Prevent Display Sleep" as CFString,
                &id
            )
            if result == kIOReturnSuccess {
                if PreventDisplaySleepAction.assertionID != 0 {
                    IOPMAssertionRelease(PreventDisplaySleepAction.assertionID)
                }
                PreventDisplaySleepAction.assertionID = id
            } else {
                throw SleepPreventionError.assertionFailed(code: result)
            }
        case "off":
            if PreventDisplaySleepAction.assertionID != 0 {
                IOPMAssertionRelease(PreventDisplaySleepAction.assertionID)
                PreventDisplaySleepAction.assertionID = 0
            }
        default:
            throw SleepPreventionError.invalidState(state: state)
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "state",
                label: "State",
                description: "'on' to prevent display sleep, 'off' to allow it.",
                required: true
            ),
        ]
    }
}

public final class PreventSystemSleepAction: BaseAction {

    private static var assertionID: IOPMAssertionID = 0

    public override var pluginIdentifier: String  { "com.controlplane.action.preventsystemsleep" }
    public override var pluginDisplayName: String { "Prevent System Sleep" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let state = config["state"], !state.isEmpty else {
            throw SleepPreventionError.missingState
        }
        switch state.lowercased() {
        case "on":
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "ControlPlane: Prevent System Sleep" as CFString,
                &id
            )
            if result == kIOReturnSuccess {
                if PreventSystemSleepAction.assertionID != 0 {
                    IOPMAssertionRelease(PreventSystemSleepAction.assertionID)
                }
                PreventSystemSleepAction.assertionID = id
            } else {
                throw SleepPreventionError.assertionFailed(code: result)
            }
        case "off":
            if PreventSystemSleepAction.assertionID != 0 {
                IOPMAssertionRelease(PreventSystemSleepAction.assertionID)
                PreventSystemSleepAction.assertionID = 0
            }
        default:
            throw SleepPreventionError.invalidState(state: state)
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "state",
                label: "State",
                description: "'on' to prevent system sleep, 'off' to allow it.",
                required: true
            ),
        ]
    }
}

public enum SleepPreventionError: LocalizedError {
    case missingState
    case invalidState(state: String)
    case assertionFailed(code: IOReturn)

    public var errorDescription: String? {
        switch self {
        case .missingState:
            return "SleepPreventionAction: no state in config"
        case .invalidState(let s):
            return "SleepPreventionAction: invalid state '\(s)'; expected 'on' or 'off'"
        case .assertionFailed(let code):
            return "SleepPreventionAction: IOPMAssertionCreateWithName failed with code \(code)"
        }
    }
}

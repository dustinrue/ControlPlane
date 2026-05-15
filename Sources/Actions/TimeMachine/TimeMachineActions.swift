import Foundation
import ControlPlaneSDK

public final class StartTimeMachineAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.starttimemachine" }
    public override var pluginDisplayName: String { "Start Time Machine Backup" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        try await runProcess(executable: "/usr/bin/tmutil", arguments: ["startbackup"])
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        []
    }
}

public final class SetTimeMachineDestinationAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.timemachinedestination" }
    public override var pluginDisplayName: String { "Set Time Machine Destination" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let dest = config["destination"], !dest.isEmpty else {
            throw TimeMachineDestinationError.missingDestination
        }
        try await runProcess(executable: "/usr/bin/tmutil", arguments: ["setdestination", dest])
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "destination",
                label: "Destination",
                description: "Path or URL of the Time Machine backup destination.",
                required: true
            ),
        ]
    }
}

public enum TimeMachineDestinationError: LocalizedError {
    case missingDestination

    public var errorDescription: String? {
        switch self {
        case .missingDestination:
            return "SetTimeMachineDestinationAction: no destination in config"
        }
    }
}

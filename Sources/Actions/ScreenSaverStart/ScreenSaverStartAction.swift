import Foundation
import ControlPlaneSDK

public final class ScreenSaverStartAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.startscreensaver" }
    public override var pluginDisplayName: String { "Start Screen Saver" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        try await runProcess(executable: "/usr/bin/open", arguments: ["-a", "ScreenSaverEngine"])
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        []
    }
}

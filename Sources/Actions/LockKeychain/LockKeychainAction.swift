import Foundation
import ControlPlaneSDK

public final class LockKeychainAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.lockkeychain" }
    public override var pluginDisplayName: String { "Lock Keychain" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        try await runProcess(executable: "/usr/bin/security", arguments: ["lock-keychain", "-a"])
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        []
    }
}

import Foundation
import ControlPlaneSDK

public final class ShellScriptAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.shellscript" }
    public override var pluginDisplayName: String { "Run Shell Script" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let scriptPath = config["scriptPath"], !scriptPath.isEmpty else {
            throw ShellScriptActionError.missingScriptPath
        }
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw ShellScriptActionError.scriptNotFound(path: scriptPath)
        }
        let args: [String]
        if let argString = config["arguments"], !argString.isEmpty {
            args = argString.components(separatedBy: " ")
        } else {
            args = []
        }
        try await runProcess(executable: scriptPath, arguments: args)
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "scriptPath",
                label: "Script Path",
                description: "Absolute path to the shell script to execute.",
                required: true
            ),
            ActionConfigDescriptor(
                key: "arguments",
                label: "Arguments",
                description: "Space-separated arguments to pass to the script.",
                required: false
            ),
        ]
    }
}

public enum ShellScriptActionError: LocalizedError {
    case missingScriptPath
    case scriptNotFound(path: String)

    public var errorDescription: String? {
        switch self {
        case .missingScriptPath:
            return "ShellScriptAction: no scriptPath in config"
        case .scriptNotFound(let path):
            return "ShellScriptAction: script not found at \(path)"
        }
    }
}

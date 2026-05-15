import Foundation
import ControlPlaneSDK

public final class DefaultPrinterAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.defaultprinter" }
    public override var pluginDisplayName: String { "Set Default Printer" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let name = config["printerName"], !name.isEmpty else {
            throw DefaultPrinterActionError.missingPrinterName
        }
        try await runProcess(executable: "/usr/bin/lpoptions", arguments: ["-d", name])
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "printerName",
                label: "Printer Name",
                description: "CUPS printer name to set as default.",
                required: true
            ),
        ]
    }
}

public enum DefaultPrinterActionError: LocalizedError {
    case missingPrinterName

    public var errorDescription: String? {
        switch self {
        case .missingPrinterName:
            return "DefaultPrinterAction: no printerName in config"
        }
    }
}

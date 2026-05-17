import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @AppStorage("com.controlplane.logLevel") private var logLevelRaw: Int = CPLogLevel.off.rawValue

    private var logLevel: Binding<CPLogLevel> {
        Binding(
            get: { CPLogLevel(rawValue: logLevelRaw) ?? .off },
            set: { logLevelRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Log level:", selection: logLevel) {
                    ForEach(CPLogLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Logs are written to the Apple Unified Log.")
                        .foregroundStyle(.secondary)
                    Text("To view them, open Console.app and filter by subsystem:")
                        .foregroundStyle(.secondary)
                    Text("com.controlplane.app")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)

                Button("Open Console.app") {
                    NSWorkspace.shared.open(
                        URL(fileURLWithPath: "/System/Applications/Utilities/Console.app")
                    )
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Logging")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 500, height: 300)
}

// swift-tools-version: 6.2
import PackageDescription

// Test harness for plain language ControlPlane configuration via Apple Foundation Models.
// Requires macOS 26+ (Xcode 26 SDK) with Apple Intelligence enabled on the device.
// Must be built with Xcode — the FoundationModels macro plugin is not in the CLI tools.
// Open in Xcode and run, or: swift run NLConfig
let package = Package(
    name: "NLConfig",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "NLConfig",
            path: "Sources/NLConfig",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

// Test harness for plain language ControlPlane configuration via Apple Foundation Models.
// Requires macOS 15.4+ with Apple Intelligence enabled on the device.
// Open in Xcode and run, or: swift run NLConfig
let package = Package(
    name: "NLConfig",
    platforms: [.macOS(.v15)],
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

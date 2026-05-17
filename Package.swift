// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ControlPlane",
    platforms: [.macOS(.v14)],
    products: [
        // Core SDK — shared types and protocols used by every target
        .library(name: "ControlPlaneSDK", targets: ["ControlPlaneSDK"]),

        // Sensor plugins  (Sources/Sensors/<Name>/)
        .library(name: "WiFiSensor",               targets: ["WiFiSensor"]),
        .library(name: "FilePresenceSensor",        targets: ["FilePresenceSensor"]),
        .library(name: "PowerSensor",               targets: ["PowerSensor"]),
        .library(name: "MonitorSensor",             targets: ["MonitorSensor"]),
        .library(name: "ActiveApplicationSensor",   targets: ["ActiveApplicationSensor"]),
        .library(name: "RunningApplicationSensor",  targets: ["RunningApplicationSensor"]),
        .library(name: "MountedVolumeSensor",       targets: ["MountedVolumeSensor"]),
        .library(name: "ScreenLockSensor",          targets: ["ScreenLockSensor"]),
        .library(name: "USBSensor",                 targets: ["USBSensor"]),
        .library(name: "BluetoothSensor",           targets: ["BluetoothSensor"]),
        .library(name: "NetworkLinkSensor",         targets: ["NetworkLinkSensor"]),
        .library(name: "IPAddressSensor",           targets: ["IPAddressSensor"]),
        .library(name: "DNSSensor",                 targets: ["DNSSensor"]),
        .library(name: "AudioOutputSensor",         targets: ["AudioOutputSensor"]),
        .library(name: "LaptopLidSensor",           targets: ["LaptopLidSensor"]),
        .library(name: "TimeOfDaySensor",           targets: ["TimeOfDaySensor"]),
        .library(name: "HostAvailabilitySensor",    targets: ["HostAvailabilitySensor"]),

        // Evaluator plugins  (Sources/Evaluators/<Name>/)
        .library(name: "BuiltinEvaluator", targets: ["BuiltinEvaluator"]),

        // Action plugins  (Sources/Actions/<Name>/)
        .library(name: "ShortcutAction",          targets: ["ShortcutAction"]),
        .library(name: "ShellScriptAction",        targets: ["ShellScriptAction"]),
        .library(name: "OpenAction",               targets: ["OpenAction"]),
        .library(name: "OpenURLAction",            targets: ["OpenURLAction"]),
        .library(name: "OpenAndHideAction",        targets: ["OpenAndHideAction"]),
        .library(name: "QuitApplicationAction",    targets: ["QuitApplicationAction"]),
        .library(name: "SpeakAction",              targets: ["SpeakAction"]),
        .library(name: "MountVolumeAction",        targets: ["MountVolumeAction"]),
        .library(name: "UnmountVolumeAction",      targets: ["UnmountVolumeAction"]),
        .library(name: "DesktopBackgroundAction",  targets: ["DesktopBackgroundAction"]),
        .library(name: "ToggleWiFiAction",         targets: ["ToggleWiFiAction"]),
        .library(name: "TimeMachineAction",        targets: ["TimeMachineAction"]),
        .library(name: "SleepPreventionAction",    targets: ["SleepPreventionAction"]),
        .library(name: "ScreenSaverStartAction",   targets: ["ScreenSaverStartAction"]),
        .library(name: "LockKeychainAction",       targets: ["LockKeychainAction"]),
        .library(name: "NetworkLocationAction",    targets: ["NetworkLocationAction"]),
        .library(name: "DefaultPrinterAction",     targets: ["DefaultPrinterAction"]),

        // Executables
        .executable(name: "ControlPlane", targets: ["ControlPlaneApp"]),
        .executable(name: "cpctl",        targets: ["cpctl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [

        // MARK: - Core SDK

        .target(
            name: "ControlPlaneSDK",
            path: "Sources/ControlPlaneSDK",
            linkerSettings: [
                .linkedFramework("SystemConfiguration"),
            ]
        ),

        // MARK: - Sensor plugins

        .target(
            name: "WiFiSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/WiFi",
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
            ]
        ),
        .target(
            name: "FilePresenceSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/FilePresence"
        ),
        .target(
            name: "PowerSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/Power",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        .target(
            name: "MonitorSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/Monitor",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .target(
            name: "ActiveApplicationSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/ActiveApplication",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .target(
            name: "RunningApplicationSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/RunningApplication",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .target(
            name: "MountedVolumeSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/MountedVolume",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .target(
            name: "ScreenLockSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/ScreenLock"
        ),
        .target(
            name: "USBSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/USB",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        .target(
            name: "BluetoothSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/Bluetooth",
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
            ]
        ),
        .target(
            name: "NetworkLinkSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/NetworkLink",
            linkerSettings: [
                .linkedFramework("SystemConfiguration"),
            ]
        ),
        .target(
            name: "IPAddressSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/IPAddress",
            linkerSettings: [
                .linkedFramework("SystemConfiguration"),
            ]
        ),
        .target(
            name: "DNSSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/DNS",
            linkerSettings: [
                .linkedFramework("SystemConfiguration"),
            ]
        ),
        .target(
            name: "AudioOutputSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/AudioOutput",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
            ]
        ),
        .target(
            name: "LaptopLidSensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/LaptopLid",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        .target(
            name: "TimeOfDaySensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/TimeOfDay"
        ),
        .target(
            name: "HostAvailabilitySensor",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Sensors/HostAvailability",
            linkerSettings: [
                .linkedFramework("SystemConfiguration"),
            ]
        ),

        // MARK: - Evaluator plugins

        .target(
            name: "BuiltinEvaluator",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Evaluators/Default"
        ),

        // MARK: - Action plugins

        .target(
            name: "ShortcutAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/Shortcut"
        ),
        .target(
            name: "ShellScriptAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/ShellScript"
        ),
        .target(
            name: "OpenAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/Open"
        ),
        .target(
            name: "OpenURLAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/OpenURL"
        ),
        .target(
            name: "OpenAndHideAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/OpenAndHide"
        ),
        .target(
            name: "QuitApplicationAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/QuitApplication"
        ),
        .target(
            name: "SpeakAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/Speak"
        ),
        .target(
            name: "MountVolumeAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/MountVolume"
        ),
        .target(
            name: "UnmountVolumeAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/UnmountVolume"
        ),
        .target(
            name: "DesktopBackgroundAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/DesktopBackground"
        ),
        .target(
            name: "ToggleWiFiAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/ToggleWiFi",
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
            ]
        ),
        .target(
            name: "TimeMachineAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/TimeMachine"
        ),
        .target(
            name: "SleepPreventionAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/SleepPrevention",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        .target(
            name: "ScreenSaverStartAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/ScreenSaverStart"
        ),
        .target(
            name: "LockKeychainAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/LockKeychain"
        ),
        .target(
            name: "NetworkLocationAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/NetworkLocation"
        ),
        .target(
            name: "DefaultPrinterAction",
            dependencies: ["ControlPlaneSDK"],
            path: "Sources/Actions/DefaultPrinter"
        ),

        // MARK: - Main app

        .executableTarget(
            name: "ControlPlaneApp",
            dependencies: [
                "ControlPlaneSDK",
                "WiFiSensor",
                "FilePresenceSensor",
                "PowerSensor",
                "MonitorSensor",
                "ActiveApplicationSensor",
                "RunningApplicationSensor",
                "MountedVolumeSensor",
                "ScreenLockSensor",
                "USBSensor",
                "BluetoothSensor",
                "NetworkLinkSensor",
                "IPAddressSensor",
                "DNSSensor",
                "AudioOutputSensor",
                "LaptopLidSensor",
                "TimeOfDaySensor",
                "HostAvailabilitySensor",
                "BuiltinEvaluator",
                "ShortcutAction",
                "ShellScriptAction",
                "OpenAction",
                "OpenURLAction",
                "OpenAndHideAction",
                "QuitApplicationAction",
                "SpeakAction",
                "MountVolumeAction",
                "UnmountVolumeAction",
                "DesktopBackgroundAction",
                "ToggleWiFiAction",
                "TimeMachineAction",
                "SleepPreventionAction",
                "ScreenSaverStartAction",
                "LockKeychainAction",
                "NetworkLocationAction",
                "DefaultPrinterAction",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/ControlPlaneApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("ServiceManagement"),
            ]
        ),

        // MARK: - CLI tool

        .executableTarget(
            name: "cpctl",
            dependencies: [
                "ControlPlaneSDK",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/cpctl"
        ),
    ]
)

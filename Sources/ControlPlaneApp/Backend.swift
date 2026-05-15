import Foundation
import ControlPlaneSDK
import WiFiSensor
import FilePresenceSensor
import PowerSensor
import MonitorSensor
import ActiveApplicationSensor
import RunningApplicationSensor
import MountedVolumeSensor
import ScreenLockSensor
import USBSensor
import BluetoothSensor
import NetworkLinkSensor
import IPAddressSensor
import DNSSensor
import AudioOutputSensor
import LaptopLidSensor
import TimeOfDaySensor
import HostAvailabilitySensor
import BuiltinEvaluator
import ShortcutAction
import ShellScriptAction
import OpenAction
import OpenURLAction
import OpenAndHideAction
import QuitApplicationAction
import SpeakAction
import MountVolumeAction
import UnmountVolumeAction
import DesktopBackgroundAction
import ToggleWiFiAction
import TimeMachineAction
import SleepPreventionAction
import ScreenSaverStartAction
import LockKeychainAction
import NetworkLocationAction
import DefaultPrinterAction

/// Top-level coordinator. Owns the database, socket server, profile store,
/// plugin loader, plugin registry, sensor coordinator, rule store, and rule engine.
final class Backend {
    let appDatabase: AppDatabase
    let profileStore: ProfileStore
    let ruleStore: RuleStore
    let pluginRegistry = PluginRegistry()
    let evaluatorRegistry = EvaluatorRegistry()
    let actionRegistry = ActionRegistry()
    let sensorConfigStore = SensorConfigStore()
    lazy var sensorCoordinator = SensorCoordinator(configStore: sensorConfigStore)
    lazy var ruleEngine = RuleEngine(
        ruleStore: ruleStore,
        profileStore: profileStore,
        evaluatorRegistry: evaluatorRegistry
    )
    lazy var profileActionStore = ProfileActionStore(db: appDatabase)
    lazy var profileActivationManager = ProfileActivationManager(
        actionStore: profileActionStore,
        actionRegistry: actionRegistry,
        profileStore: profileStore
    )
    let startedAt = Date()
    private let locationAuthorizer = LocationAuthorizer()

    private lazy var pluginLoader = PluginLoader(registry: pluginRegistry, sensors: sensorCoordinator)
    private var socketServer: SocketServer?

    init() {
        do {
            appDatabase = try AppDatabase.openShared()
        } catch {
            fatalError("Failed to open database: \(error)")
        }
        profileStore = ProfileStore(db: appDatabase)
        ruleStore = RuleStore(db: appDatabase)
    }

    func start() {
        log("Starting ControlPlane backend (pid \(ProcessInfo.processInfo.processIdentifier))")
        locationAuthorizer.onAuthorized = { [weak self] in
            guard let self else { return }
            Task { await self.sensorCoordinator.refreshAllSensors() }
        }
        locationAuthorizer.requestIfNeeded()
        setupSocketServer()
        registerStaticEvaluators()
        registerStaticActions()
        registerStaticPlugins()
        pluginLoader.discoverPlugins()
        // Wire sensor updates → rule evaluation → profile activation callbacks.
        Task { [weak self] in
            guard let self else { return }
            await self.sensorCoordinator.setSnapshotCallback { [weak self] snapshots in
                guard let self else { return }
                do {
                    let active = try await self.ruleEngine.evaluate(snapshots: snapshots)
                    await self.profileActivationManager.update(active)
                } catch {
                    log("Rule evaluation error: \(error)")
                }
            }
        }
        log("Backend ready")
    }

    private func registerStaticEvaluators() {
        Task {
            await evaluatorRegistry.register(DefaultEvaluator())
        }
    }

    private func registerStaticActions() {
        Task {
            await actionRegistry.register(ShellScriptAction())
            await actionRegistry.register(OpenAction())
            await actionRegistry.register(OpenURLAction())
            await actionRegistry.register(OpenAndHideAction())
            await actionRegistry.register(QuitApplicationAction())
            await actionRegistry.register(SpeakAction())
            await actionRegistry.register(MountVolumeAction())
            await actionRegistry.register(UnmountVolumeAction())
            await actionRegistry.register(DesktopBackgroundAction())
            await actionRegistry.register(StartTimeMachineAction())
            await actionRegistry.register(SetTimeMachineDestinationAction())
            await actionRegistry.register(PreventDisplaySleepAction())
            await actionRegistry.register(PreventSystemSleepAction())
            await actionRegistry.register(ScreenSaverStartAction())
            await actionRegistry.register(LockKeychainAction())
            await actionRegistry.register(NetworkLocationAction())
            await actionRegistry.register(DefaultPrinterAction())
            if ToggleWiFiAction.isApplicable() {
                await actionRegistry.register(ToggleWiFiAction())
            }
            if ShortcutAction.isApplicable() {
                await actionRegistry.register(ShortcutAction())
            }
        }
    }

    /// Registers plugins that are statically linked into the backend binary for development.
    /// When plugins ship as proper .bundle files this list shrinks to nothing.
    private func registerStaticPlugins() {
        Task {
            await registerSensor(WiFiSensor())
            await registerSensor(FilePresenceSensor())
            await registerSensor(PowerSensor())
            await registerSensor(MonitorSensor())
            await registerSensor(ActiveApplicationSensor())
            await registerSensor(RunningApplicationSensor())
            await registerSensor(MountedVolumeSensor())
            await registerSensor(ScreenLockSensor())
            await registerSensor(USBSensor())
            await registerSensor(BluetoothSensor())
            await registerSensor(NetworkLinkSensor())
            await registerSensor(IPAddressSensor())
            await registerSensor(DNSSensor())
            await registerSensor(AudioOutputSensor())
            await registerSensor(TimeOfDaySensor())
            await registerSensor(HostAvailabilitySensor())
            if LaptopLidSensor.isApplicable() {
                await registerSensor(LaptopLidSensor())
            }
            // After sensors are registered, push current rule keys to any dynamic sensors.
            await refreshDynamicSensorKeys()
        }
    }

    /// Queries all rules and pushes each sensor's monitored key set to any
    /// DynamicKeySensor that has rules referencing it.
    /// Call this after any rule create, update, or delete.
    func refreshDynamicSensorKeys() async {
        do {
            let rules = try await ruleStore.list()
            // Group enabled rule readingKeys by sensorID for dynamic sensors only.
            var keysBySensor: [String: [String]] = [:]
            for rule in rules where rule.enabled {
                keysBySensor[rule.sensorID, default: []].append(rule.readingKey)
            }
            // For each dynamic sensor, pass its keys (or empty if no rules reference it).
            let dynamicIDs = await sensorCoordinator.dynamicSensorIDs()
            for id in dynamicIDs {
                let keys = keysBySensor[id] ?? []
                await sensorCoordinator.setMonitoredKeys(keys, forSensor: id)
            }
        } catch {
            log("refreshDynamicSensorKeys error: \(error)")
        }
    }

    private func registerSensor(_ sensor: any SensorPlugin) async {
        guard type(of: sensor).isApplicable() else {
            log("Sensor \(sensor.pluginIdentifier) is not applicable on this system — skipping")
            return
        }
        let info = PluginInfo(
            id: sensor.pluginIdentifier,
            displayName: sensor.pluginDisplayName,
            version: sensor.pluginVersion,
            category: .sensor,
            source: .bundled
        )
        await pluginRegistry.register(info)
        await sensorCoordinator.add(sensor)
    }

    private func setupSocketServer() {
        let handler = RequestHandler(
            store: profileStore,
            rules: ruleStore,
            profileActions: profileActionStore,
            registry: pluginRegistry,
            evaluators: evaluatorRegistry,
            actionTypes: actionRegistry,
            sensors: sensorCoordinator,
            ruleEngine: ruleEngine,
            activationManager: profileActivationManager,
            backend: self
        )
        let server = SocketServer(handler: handler)
        server.start()
        socketServer = server
        log("Socket server active at \(CPSocketPath)")
    }
}

func log(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(ts)] [ControlPlane] \(message)")
}

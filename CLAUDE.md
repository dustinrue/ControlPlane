# ControlPlane — Architecture Reference

Modern Swift rewrite of the original ControlPlane macOS app. Activates user-defined
profiles based on environmental sensor readings using a confidence/weight model.

**Original app** (for reference when porting features):
`/Users/dustin/Development/personal/ControlPlane/`
Consult it to understand existing behaviour, condition types, action types, and UI
conventions before implementing anything new.

---

## What it does

Sensors observe the environment (WiFi, file presence, power state, monitors, etc.) and
emit typed readings. Rules compare readings against expected values; each matching rule
contributes its weight to a profile's confidence score. When a profile's confidence meets
its threshold, it activates — running any attached actions (run a Shortcut, etc.).

```
Sensor snapshot → RuleEngine.evaluate()
  → for each profile:
       confidence = Σ weight of each matching enabled rule
       if confidence >= profile.confidenceThreshold → candidate
  → ProfileActivationManager resolves candidates → active profiles → actions fire
```

---

## Process architecture

**Single process** — the menu-bar app IS the backend. There is no separate daemon.

- `cpctl` communicates with the app over a **Unix domain socket** (not XPC).
- Socket path is defined in `ControlPlaneSDK/CPSocket.swift`.
- `SocketServer` in ControlPlaneApp listens; `RequestHandler` dispatches commands.
- `XPCClient` in cpctl sends JSON-encoded requests and reads JSON responses.

Why not XPC: required a separate daemon, entitlements, and launchd plist. The socket
approach is simpler, sufficient, and keeps everything in one process.

---

## Directory layout

```
Sources/
  ControlPlaneSDK/        # Shared types and protocols — NO app logic here
  ControlPlaneApp/        # Menu-bar app + all backend coordination
  Sensors/
    WiFi/                 # WiFiSensor module
    FilePresence/         # FilePresenceSensor module
    Power/                # PowerSensor module
    Monitor/              # MonitorSensor module
  Evaluators/
    Default/              # BuiltinEvaluator module (DefaultEvaluator class)
  Actions/
    Shortcut/             # ShortcutAction module
  cpctl/                  # CLI tool (ArgumentParser)

Resources/                # Info.plist, icons
scripts/                  # generate-icon.swift (icon generation pipeline)
```

New plugins always go into `Sources/Sensors/`, `Sources/Evaluators/`, or
`Sources/Actions/` — one directory per plugin, one Swift Package target per plugin.

---

## Key types (ControlPlaneSDK)

| Type | Purpose |
|------|---------|
| `SensorPlugin` | Protocol for all sensor plugins |
| `PushSensor` | Sensor that calls `onSnapshotChanged` on every update (event-driven) |
| `DynamicKeySensor` | Sensor whose watched keys come from rules (e.g. file paths) |
| `EvaluatorPlugin` | Compares a reading against a comparand; returns Bool |
| `ActionPlugin` | Executes an action when a profile transitions |
| `BaseAction` | `open class` base for action plugins — extend this, not `ActionPlugin` directly |
| `ControlPlanePlugin` | Base `@objc` protocol all plugins satisfy (for bundle loading) |
| `ObservationValue` | Typed sensor reading: `.string`, `.boolean`, `.number`, `.strings` |
| `Rule` | One condition: sensorID + readingKey + operator + comparand + weight |
| `Profile` | Has a `confidenceThreshold`; activates when Σ matched rule weights ≥ threshold |
| `ProfileAction` | An action instance attached to a profile with trigger + config |

---

## Plugin conventions

1. All plugins are `NSObject` subclasses — required for `Bundle.principalClass` loading.
2. Every plugin module must be a separate Swift Package target.
3. **Module name must differ from the principal class name.** Swift resolves an identifier
   as the module when both have the same name, silently breaking all call sites.
   - ✅ Module `BuiltinEvaluator`, class `DefaultEvaluator`
   - ❌ Module `DefaultEvaluator`, class `DefaultEvaluator`  ← will not compile correctly
4. All public API in a plugin module must be marked `public` (cross-module visibility).
5. Action plugins extend `BaseAction`, not `ActionPlugin` directly.
6. Sensors implement `isApplicable() -> Bool`; the loader skips inapplicable sensors.
7. Static (built-in) plugins are registered in `Backend.start()`:
   - `registerStaticEvaluators()` — always registered
   - `registerStaticActions()` — registered if `isApplicable()` returns true
   - `registerStaticPlugins()` — sensors, same applicability check
8. Third-party bundle plugins are loaded from:
   - App bundle: `Contents/Plugins/{Sensors,Actions,Intelligence}/`
   - User: `~/Library/Application Support/ControlPlane/Plugins/{Sensors,Actions,Intelligence}/`

---

## Notifications

Notifications are a **first-class app concern**, not a plugin concern.

- `Notifier` enum lives in `ControlPlaneApp/Notifier.swift`.
- `ProfileActivationManager` calls `Notifier.profileActivated/Deactivated` directly.
- Plugins must NOT send notifications.
- A startup notification fires in the UNUserNotificationCenter auth callback to confirm
  the permission flow works end-to-end.

---

## Menu bar icon

Uses an **SF Symbol** (`airplane`) via `NSImage(systemSymbolName:)` with a
`SymbolConfiguration`. This handles dark/light mode automatically without any template
image logic. Do not use a bundle image for the status item icon.

---

## App icon generation

Source: `cp-icon-source.png` (dark airplane silhouette, transparent background).
Script: `scripts/generate-icon.swift`.

**Must use `CGContext` directly** — do not use `NSGraphicsContext` or `CIImage`:
- `NSGraphicsContext` silently produces near-transparent output in script contexts
  (no run loop, premultiplied alpha issues).
- `CIImage` / `CIBlendWithLuminanceMask` either crashes (filter unavailable) or
  corrupts alpha in `writePNGRepresentation`.

The working technique: blue fill → `beginTransparencyLayer` → white fill →
`.destinationIn` blend → `endTransparencyLayer`. This produces a fully opaque icon.

Pipeline: `generate-icon.swift` → PNG files at each required size → `iconutil` → `AppIcon.icns`.

---

## Build

```bash
make build    # Universal (arm64 + x86_64) fat binaries via lipo
make run      # Build + assemble .app bundle + kill old instance + relaunch
```

The Makefile builds each arch separately with `swift build --arch`, then uses
`lipo -create` to produce universals in `.build/universal/debug/`.

`make run` copies the universal `cpctl` binary into
`ControlPlane.app/Contents/MacOS/cpctl` so the app can install it on first launch.

### cpctl auto-install

On first launch, ControlPlaneApp checks for `~/.local/bin/cpctl`. If absent, it copies
the bundled binary (resolved via `Bundle.main.path(forAuxiliaryExecutable: "cpctl")`),
codesigns it, and sends a notification. See `CpctlInstaller.swift`.

---

## ShortcutAction specifics

- Stores the shortcut **UUID** in `config["shortcutID"]` — not the name, which can change.
- `config["shortcutName"]` is optional display-only metadata.
- Executes `/usr/bin/shortcuts run <UUID>` via `Process`.
- `isApplicable()` checks that `/usr/bin/shortcuts` exists (requires macOS 12+).
- `cpctl shortcuts list` runs `shortcuts list --show-identifiers` locally (no backend
  needed) and parses `Name (UUID)` lines into a formatted table.

---

## Things that will burn you

| Trap | What happens | Fix |
|------|-------------|-----|
| Module name == class name | Swift resolves identifier as module; `Foo()` fails to compile | Name the module differently |
| Missing `public` on cross-module types | Compiles within module, breaks at import site | Make all protocol members `public` |
| `NSGraphicsContext` in scripts | Near-transparent output, no error | Use raw `CGContext` |
| Notification plugin approach | Every profile needs a DB action record to get a notification | Put notifications in `Notifier`, not plugins |
| Shortcut name in config | User renames shortcut → action silently breaks | Store UUID; display name is cosmetic only |
| `isTemplate = true` with white icon | Icon invisible on light menu bar | Use SF Symbol instead |
| IOBluetooth in `isApplicable()` | TCC check fires at registration time (before app UI), hard crash | Never touch IOBluetooth in `isApplicable()` — just `return true` |
| IOBluetooth in `start()` immediately | TCC crash if Bluetooth not yet authorized — happens even with usage description | Defer all IOBluetooth calls by ≥2 s via `Task.sleep` so the app is fully running and can show the TCC dialog |
| Universal binary (`make run`) failing | `lipo: can't open input file` for new modules | New modules must be built for both arches: `swift build --arch x86_64 --product ControlPlane` once to prime the cache |

---

## Implemented sensor plugins

All new sensors extend `BaseSensor` (in `ControlPlaneSDK`). `BaseSensor` implements
`SensorPlugin` + `PushSensor`, manages the `NSLock`-protected snapshot, and exposes
`publishSnapshot(readings:isActive:)` / `publishInactive()` helpers. Existing sensors
(WiFi, Power, FilePresence, Monitor) predate `BaseSensor` and keep their own pattern.

| Module | Class | pluginIdentifier | Type | Notes |
|--------|-------|-----------------|------|-------|
| `WiFiSensor` | `WiFiSensor` | `com.controlplane.sensors.wifi` | Push+Dynamic+Configurable | Pre-BaseSensor |
| `PowerSensor` | `PowerSensor` | `com.controlplane.sensors.power` | Push | Pre-BaseSensor |
| `FilePresenceSensor` | `FilePresenceSensor` | `com.controlplane.sensors.filepresence` | Push+Dynamic | Pre-BaseSensor |
| `MonitorSensor` | `MonitorSensor` | `com.controlplane.sensors.monitor` | Push | Pre-BaseSensor |
| `ActiveApplicationSensor` | `ActiveApplicationSensor` | `com.controlplane.sensors.activeapplication` | Push | NSWorkspace notifications; reads `bundleID`, `name` |
| `RunningApplicationSensor` | `RunningApplicationSensor` | `com.controlplane.sensors.runningapplication` | Push+Dynamic | Keys are bundle IDs; reading per key → boolean |
| `MountedVolumeSensor` | `MountedVolumeSensor` | `com.controlplane.sensors.mountedvolume` | Push | NSWorkspace mount/unmount; reads `mounted` (strings) + per-volume boolean |
| `ScreenLockSensor` | `ScreenLockSensor` | `com.controlplane.sensors.screenlock` | Push | DistributedNotificationCenter; reads `locked` boolean |
| `USBSensor` | `USBSensor` | `com.controlplane.sensors.usb` | Push+Dynamic | IOKit; keys are `"vendorID:productID"`; reads `devices` strings |
| `BluetoothSensor` | `BluetoothSensor` | `com.controlplane.sensors.bluetooth` | Push | IOBluetooth; reads `powered`, `devices`, per-MAC boolean |
| `NetworkLinkSensor` | `NetworkLinkSensor` | `com.controlplane.sensors.networklink` | Push | SCDynamicStore; reads per-interface boolean + `activeInterfaces` |
| `IPAddressSensor` | `IPAddressSensor` | `com.controlplane.sensors.ipaddress` | Push | SCDynamicStore; reads `<iface>.ipv4`, `<iface>.ipv6`, `allAddresses` |
| `DNSSensor` | `DNSSensor` | `com.controlplane.sensors.dns` | Push | SCDynamicStore; reads `searchDomains`, `servers`, `primaryDomain` |
| `AudioOutputSensor` | `AudioOutputSensor` | `com.controlplane.sensors.audiooutput` | Push | CoreAudio; reads `outputDevice`, `outputDeviceUID` |
| `LaptopLidSensor` | `LaptopLidSensor` | `com.controlplane.sensors.laptoplid` | Push | IOKit PM; reads `lidClosed`; `isApplicable()` checks `AppleClamshellExists` |
| `TimeOfDaySensor` | `TimeOfDaySensor` | `com.controlplane.sensors.timeofday` | Poll (1 min) | Reads `hour`, `minute`, `time` (HH:mm), `dayOfWeek` |
| `HostAvailabilitySensor` | `HostAvailabilitySensor` | `com.controlplane.sensors.hostavailability` | Push+Dynamic | SCNetworkReachability per hostname; keys are hostnames |

Sensors intentionally NOT ported: FireWire (dead technology), Bonjour (complex, niche),
ShellScript evidence source (polling, overlap with ShellScriptAction), Light (private API),
ScreenSaver time/RemoteDesktop (niche), ContextEvidenceSource (ControlPlane-internal),
StressTest (internal only).

## Implemented action plugins

All actions extend `BaseAction` (in `ControlPlaneSDK`). `BaseAction` provides a
`runProcess(executable:arguments:) async throws -> String` helper used by most actions.

| Module | Class(es) | pluginIdentifier | Notes |
|--------|-----------|-----------------|-------|
| `ShortcutAction` | `ShortcutAction` | `com.controlplane.action.shortcut` | config: `shortcutID`, `shortcutName` |
| `ShellScriptAction` | `ShellScriptAction` | `com.controlplane.action.shellscript` | config: `scriptPath`, `arguments` |
| `OpenAction` | `OpenAction` | `com.controlplane.action.open` | config: `path` |
| `OpenURLAction` | `OpenURLAction` | `com.controlplane.action.openurl` | config: `url` |
| `OpenAndHideAction` | `OpenAndHideAction` | `com.controlplane.action.openandhide` | config: `path` |
| `QuitApplicationAction` | `QuitApplicationAction` | `com.controlplane.action.quitapplication` | config: `bundleIdentifier`, `force` |
| `SpeakAction` | `SpeakAction` | `com.controlplane.action.speak` | config: `text`, `voice` |
| `MountVolumeAction` | `MountVolumeAction` | `com.controlplane.action.mountvolume` | config: `serverURL` (smb://, afp://) |
| `UnmountVolumeAction` | `UnmountVolumeAction` | `com.controlplane.action.unmountvolume` | config: `volumePath` |
| `DesktopBackgroundAction` | `DesktopBackgroundAction` | `com.controlplane.action.desktopbackground` | config: `imagePath`, `screen` (all/main) |
| `ToggleWiFiAction` | `ToggleWiFiAction` | `com.controlplane.action.togglewifi` | config: `state` (on/off); `isApplicable()` guarded |
| `TimeMachineAction` | `StartTimeMachineAction` | `com.controlplane.action.starttimemachine` | no config |
| `TimeMachineAction` | `SetTimeMachineDestinationAction` | `com.controlplane.action.timemachinedestination` | config: `destination` |
| `SleepPreventionAction` | `PreventDisplaySleepAction` | `com.controlplane.action.preventdisplaysleep` | config: `state` (on/off) |
| `SleepPreventionAction` | `PreventSystemSleepAction` | `com.controlplane.action.preventsystemsleep` | config: `state` (on/off) |
| `ScreenSaverStartAction` | `ScreenSaverStartAction` | `com.controlplane.action.startscreensaver` | no config |
| `LockKeychainAction` | `LockKeychainAction` | `com.controlplane.action.lockkeychain` | no config |
| `NetworkLocationAction` | `NetworkLocationAction` | `com.controlplane.action.networklocation` | config: `locationName` |
| `DefaultPrinterAction` | `DefaultPrinterAction` | `com.controlplane.action.defaultprinter` | config: `printerName` |

Actions intentionally NOT ported (require private APIs, are obsolete, or need sudo):
`DisplayBrightnessAction` (private IOKit), `ToggleBluetoothAction` (private IOBluetooth),
`VPNAction` (no clean public API), `ToggleRemoteLoginAction` (requires sudo),
`ITunesPlaylistAction` (iTunes gone), Mail/Messages actions (too brittle),
FTP/TFTP/WebSharing (removed from macOS), `ToggleNotificationCenterAlertsAction`
(Focus mode now, completely different API).

## Pending / planned work

See `docs/rules-engine.md` for the full rules engine design. Outstanding items:

- GUI for profile/rule/action management (no UI exists yet beyond the menu bar)
- `cpctl profiles active` — show currently active profiles with confidence scores
- Per-profile action configuration via `cpctl actions add`
- `cpctl rules list/add/remove/update` — already implemented in the socket handler,
  needs cpctl commands wired up completely
- Evaluator registry exposed via `cpctl evaluators list`

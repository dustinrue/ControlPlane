# ControlPlane

> **⚠️ Alpha software.** ControlPlane is under active development. Expect bugs, missing features, and breaking changes between releases. It is not yet suitable for daily use.

ControlPlane is a macOS menu-bar app that automatically switches your Mac's configuration based on where you are and what's happening around you. Connect to your home Wi-Fi and your "Home" profile activates — closing apps, changing your default printer, mounting a network share. Plug in your work monitor and your "Work" profile takes over. Disconnect from both and everything reverts.

This is a modern Swift rewrite of the [original ControlPlane](https://github.com/dustinrue/ControlPlane/tree/master), rebuilt from the ground up for current macOS.

---

## How it works

**Sensors** observe the environment continuously — Wi-Fi networks, connected Bluetooth devices, USB peripherals, power state, screen lock status, time of day, and more.

**Rules** compare sensor readings against expected values. Each matching rule contributes a confidence weight toward its profile.

**Profiles** activate when their confidence threshold is met. A profile with a single rule and the default threshold activates as soon as that one rule matches. Multiple rules let you require more specific conditions.

**Actions** fire when a profile activates or deactivates — run a macOS Shortcut, execute a shell script, open or quit an application, change your desktop background, and more.

```
Wi-Fi SSID = "HomeNetwork"  → +1.0 confidence
Bluetooth "AirPods" connected → +1.0 confidence
                                             ↓
                              Profile "Home" threshold: 1.0 → ACTIVE
                                             ↓
                              Actions: mount NAS, set default printer
```

---

## Sensors

| Sensor | What it detects |
|--------|----------------|
| Wi-Fi | Connected network SSID, BSSID, signal strength |
| Bluetooth | Connected devices, adapter power state |
| USB | Connected devices by vendor/product ID |
| Power | Battery vs. AC, charging state, low power mode |
| Network Link | Active network interfaces |
| IP Address | Assigned addresses per interface |
| DNS | Servers, search domains |
| Monitor | Connected displays, external display count |
| Mounted Volume | Attached disks and network shares |
| Active Application | Frontmost app |
| Running Application | Whether a specific app is running |
| Screen Lock | Locked/unlocked state |
| Laptop Lid | Open/closed state |
| Audio Output | Active output device |
| Host Availability | Whether a hostname is reachable |
| Time of Day | Hour, minute, day of week |
| File Presence | Whether a file or directory exists |

---

## Actions

| Action | What it does |
|--------|-------------|
| Run Shortcut | Execute a macOS Shortcut by UUID |
| Shell Script | Run any script with arguments |
| Open | Open a file, app, or folder |
| Open URL | Open a URL in the default browser |
| Open & Hide | Open an app and immediately hide it |
| Quit Application | Quit (or force-quit) an app by bundle ID |
| Speak | Speak text via the system voice |
| Mount Volume | Mount an SMB or AFP network share |
| Unmount Volume | Eject a volume |
| Desktop Background | Change wallpaper on one or all screens |
| Toggle Wi-Fi | Turn Wi-Fi on or off |
| Start Time Machine | Trigger a Time Machine backup |
| Set Time Machine Destination | Switch backup target |
| Prevent Display Sleep | Enable or disable display sleep prevention |
| Prevent System Sleep | Enable or disable system sleep prevention |
| Start Screen Saver | Launch the screen saver immediately |
| Lock Keychain | Lock the default keychain |
| Network Location | Switch macOS network location |
| Default Printer | Change the default printer |

---

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

---

## Building from source

Requires Xcode 15+ and Swift 5.9+.

```bash
# Build universal binaries (arm64 + x86_64)
make build

# Build, assemble app bundle, and launch
make run
```

### cpctl

ControlPlane ships with `cpctl`, a command-line interface for managing profiles, rules, and actions without a GUI. On first launch the app installs it to `~/.local/bin/cpctl`.

```bash
cpctl status
cpctl profiles list
cpctl rules list
cpctl sensors readings
cpctl evaluators list
cpctl --help
```

---

## Status

This rewrite is **alpha**. The core engine is functional — sensors run, rules evaluate, profiles activate, actions fire — but the following are not yet complete:

- **No GUI** beyond the menu bar icon. All configuration is done via `cpctl`.
- **No auto-update** mechanism.
- **No code signing or notarization** for distribution builds.
- The database schema may change between versions with no migration path.

The original Objective-C ControlPlane is preserved on the [`master`](https://github.com/dustinrue/ControlPlane/tree/master) branch for reference.

---

## License

MIT

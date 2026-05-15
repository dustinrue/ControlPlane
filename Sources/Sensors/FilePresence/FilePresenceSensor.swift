import Foundation
import ControlPlaneSDK

/// Sensor that reports whether files exist at paths referenced by rules.
///
/// This sensor is a singleton — it does not have a configurable path.
/// Instead, the rule's `readingKey` IS the file path:
///
///   sensor:    com.controlplane.sensors.filepresence
///   key:       /path/to/file          ← the absolute path
///   operator:  equals
///   comparand: true
///
/// The backend calls `setMonitoredKeys(_:)` after loading rules and whenever
/// rules change. The snapshot contains one reading per monitored path
/// (key = path, value = boolean).
///
/// ## File system monitoring
///
/// Rather than polling, the sensor watches the **parent directory** of every
/// monitored path using `DispatchSourceFileSystemObject` (kqueue NOTE_WRITE).
/// macOS fires that event whenever a file is created, removed, or renamed
/// inside the directory, so the sensor reacts instantly with no CPU overhead
/// between events.
///
/// When `setMonitoredKeys` is called the old watches are torn down and new
/// ones are set up for the current set of parent directories.
public final class FilePresenceSensor: NSObject, SensorPlugin, DynamicKeySensor, PushSensor {
    public var pluginIdentifier: String { "com.controlplane.sensors.filepresence" }
    public var pluginDisplayName: String { "File Presence" }
    public var pluginVersion: String { "1.0.0" }
    public var pluginCategory: String { "sensor" }

    /// Injected by SensorCoordinator. Called after every snapshot update.
    public var onSnapshotChanged: (@Sendable () -> Void)?

    // NSLock guards _snapshot and _monitoredPaths.
    private let lock = NSLock()
    private var _snapshot: SensorSnapshot
    private var _monitoredPaths: [String] = []

    // Active directory watches keyed by directory path.
    // Access only from watchQueue.
    private let watchQueue = DispatchQueue(label: "com.controlplane.sensors.filepresence.watches")
    private var directoryWatches: [String: (fd: Int32, source: any DispatchSourceFileSystemObject)] = [:]

    public override required init() {
        _snapshot = SensorSnapshot(
            sensorID: "com.controlplane.sensors.filepresence",
            displayName: "File Presence",
            readings: [],
            isActive: false
        )
        super.init()
    }

    public static func isApplicable() -> Bool { true }

    public func start() async {
        refreshSnapshot()
        // Watches are set up (or refreshed) in setMonitoredKeys, which the
        // backend calls right after start(). Nothing extra needed here.
    }

    public func stop() async {
        lock.withLock {
            _monitoredPaths = []
            _snapshot = SensorSnapshot(
                sensorID: pluginIdentifier,
                displayName: pluginDisplayName,
                readings: [],
                isActive: false
            )
        }
        cancelAllWatches()
    }

    public func currentSnapshot() async -> SensorSnapshot {
        lock.withLock { _snapshot }
    }

    public func refresh() async {
        refreshSnapshot()
    }

    // MARK: - DynamicKeySensor

    public func setMonitoredKeys(_ keys: [String]) {
        lock.withLock { _monitoredPaths = keys }
        refreshSnapshot()
        rebuildWatches(for: keys)
    }

    // MARK: - Snapshot

    private func refreshSnapshot() {
        let paths = lock.withLock { _monitoredPaths }

        let readings: [SensorReading] = paths.map { path in
            let exists = FileManager.default.fileExists(atPath: path)
            let label  = URL(fileURLWithPath: path).lastPathComponent
            return SensorReading(key: path, label: label, value: .boolean(exists))
        }

        let snap = SensorSnapshot(
            sensorID: pluginIdentifier,
            displayName: pluginDisplayName,
            readings: readings,
            isActive: true
        )
        lock.withLock { _snapshot = snap }
        onSnapshotChanged?()
    }

    // MARK: - Directory watches

    /// Rebuild watches for the unique set of parent directories of `paths`.
    /// Called on `watchQueue` to serialise watch lifecycle.
    private func rebuildWatches(for paths: [String]) {
        let parentDirs = Set(paths.map {
            URL(fileURLWithPath: $0).deletingLastPathComponent().path
        })

        watchQueue.async { [weak self] in
            guard let self else { return }
            // Cancel watches for directories that are no longer needed.
            for dir in self.directoryWatches.keys where !parentDirs.contains(dir) {
                self.cancelWatch(for: dir)
            }
            // Add watches for newly-needed directories.
            for dir in parentDirs where self.directoryWatches[dir] == nil {
                self.addWatch(for: dir)
            }
        }
    }

    /// Install a kqueue watch on `dir`. Must be called on `watchQueue`.
    private func addWatch(for dir: String) {
        // O_EVTONLY opens the path for event monitoring without preventing
        // the file system from unmounting.
        let fd = open(dir, O_EVTONLY)
        guard fd >= 0 else {
            print("[FilePresenceSensor] cannot watch directory \(dir): open failed (errno \(errno))")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            // NOTE_WRITE fires when the directory's contents change
            // (file created, deleted, or renamed inside it).
            // NOTE_DELETE / NOTE_RENAME cover the directory itself going away.
            eventMask: [.write, .delete, .rename],
            queue: watchQueue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.refreshSnapshot()

            // If the directory itself was deleted/renamed the watch is now
            // stale. Tear it down; the sensor will have no way to detect
            // new files until setMonitoredKeys is called again (e.g. when
            // the rule engine re-evaluates and the backend refreshes keys).
            let events = source.data
            if events.contains(.delete) || events.contains(.rename) {
                self.cancelWatch(for: dir)
            }
        }

        source.setCancelHandler { close(fd) }
        source.resume()

        directoryWatches[dir] = (fd: fd, source: source)
        print("[FilePresenceSensor] watching directory: \(dir)")
    }

    /// Cancel and remove the watch for `dir`. Must be called on `watchQueue`.
    private func cancelWatch(for dir: String) {
        guard let entry = directoryWatches.removeValue(forKey: dir) else { return }
        entry.source.cancel()
        // fd is closed in the cancel handler set up in addWatch.
        print("[FilePresenceSensor] stopped watching directory: \(dir)")
    }

    /// Cancel all active watches. Safe to call from any thread.
    private func cancelAllWatches() {
        watchQueue.async { [weak self] in
            guard let self else { return }
            for dir in self.directoryWatches.keys {
                self.cancelWatch(for: dir)
            }
        }
    }
}

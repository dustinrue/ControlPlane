import Foundation
import AppKit
import ControlPlaneSDK
import os

private let volumeLogger = Logger(subsystem: "com.controlplane.app", category: "MountedVolumeSensor")

public final class MountedVolumeSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.mountedvolume" }
    public override var pluginDisplayName: String { "Mounted Volume" }

    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?

    public override required init() {
        super.init()
    }

    public override func start() async {
        mountObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let path = (notification.userInfo?["NSDevicePath"] as? String) ?? "unknown"
            volumeLogger.info("[MountedVolume] didMountNotification — path: \(path, privacy: .public)")
            DispatchQueue.main.async { self?.refreshSnapshot() }
        }
        unmountObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let path = (notification.userInfo?["NSDevicePath"] as? String) ?? "unknown"
            volumeLogger.info("[MountedVolume] didUnmountNotification — path: \(path, privacy: .public)")
            DispatchQueue.main.async { self?.refreshSnapshot() }
        }
        DispatchQueue.main.sync { refreshSnapshot() }
    }

    public override func stop() async {
        if let obs = mountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            mountObserver = nil
        }
        if let obs = unmountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            unmountObserver = nil
        }
        publishInactive()
    }

    private func refreshSnapshot() {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [],
            options: []
        ) ?? []
        let names = urls.map { $0.lastPathComponent }
        volumeLogger.info("[MountedVolume] refreshSnapshot — volumes: \(names.joined(separator: ", "), privacy: .public)")
        var readings: [SensorReading] = [
            SensorReading(key: "mounted", label: "Mounted Volumes", value: .strings(names))
        ]
        for name in names {
            readings.append(SensorReading(key: name, label: name, value: .boolean(true)))
        }
        publishSnapshot(readings: readings)
    }
}

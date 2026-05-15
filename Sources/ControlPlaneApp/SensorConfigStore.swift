import Foundation
import ControlPlaneSDK

/// Persists sensor option values to a JSON file in Application Support.
///
/// Storage format: { "sensor.id": { "optionKey": <SensorOptionValue> } }
actor SensorConfigStore {
    private let fileURL: URL
    private var data: [String: [String: SensorOptionValue]]

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = appSupport.appendingPathComponent("ControlPlane")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("sensor-config.json")
        fileURL = url

        // Read synchronously during init — safe because the actor isn't shared yet.
        if let raw = try? Data(contentsOf: url),
           let parsed = try? JSONDecoder().decode(
               [String: [String: SensorOptionValue]].self, from: raw
           ) {
            data = parsed
            log("Sensor config loaded from \(url.path)")
        } else {
            data = [:]
        }
    }

    // MARK: - Read

    func options(for sensorID: String) -> [String: SensorOptionValue] {
        data[sensorID] ?? [:]
    }

    // MARK: - Write

    func set(key: String, value: SensorOptionValue, for sensorID: String) {
        data[sensorID, default: [:]][key] = value
        persist()
    }

    // MARK: - Private

    private func persist() {
        do {
            let raw = try encoder.encode(data)
            try raw.write(to: fileURL, options: .atomic)
        } catch {
            log("Failed to save sensor config: \(error.localizedDescription)")
        }
    }
}

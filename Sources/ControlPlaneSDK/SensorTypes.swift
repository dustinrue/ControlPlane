import Foundation

// MARK: - Observation value

/// The typed value a sensor emits for a single reading key.
///
/// Mirrors the implicit types the old evidence sources used:
///   - string:  SSID, hostname, process name, network location name, …
///   - boolean: connected, power on, lid open, adapter plugged in, …
///   - number:  RSSI, battery %, light level, …
///   - strings: set of visible SSIDs, set of visible BSSIDs, USB device names, …
public enum ObservationValue: Sendable, Equatable, Hashable {
    case string(String)
    case boolean(Bool)
    case number(Double)
    case strings([String])
}

// MARK: Codable

extension ObservationValue: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "string":  self = .string(try c.decode(String.self,   forKey: .value))
        case "boolean": self = .boolean(try c.decode(Bool.self,    forKey: .value))
        case "number":  self = .number(try c.decode(Double.self,   forKey: .value))
        case "strings": self = .strings(try c.decode([String].self, forKey: .value))
        default: throw DecodingError.dataCorruptedError(
            forKey: .type, in: c, debugDescription: "Unknown ObservationValue type '\(type)'"
        )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let v):  try c.encode("string",  forKey: .type); try c.encode(v, forKey: .value)
        case .boolean(let v): try c.encode("boolean", forKey: .type); try c.encode(v, forKey: .value)
        case .number(let v):  try c.encode("number",  forKey: .type); try c.encode(v, forKey: .value)
        case .strings(let v): try c.encode("strings", forKey: .type); try c.encode(v, forKey: .value)
        }
    }
}

// MARK: Display

extension ObservationValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .string(let v):  return v.isEmpty ? "(empty)" : v
        case .boolean(let v): return v ? "true" : "false"
        case .number(let v):  return v.truncatingRemainder(dividingBy: 1) == 0
                                     ? String(Int(v)) : String(format: "%.2f", v)
        case .strings(let v): return v.isEmpty ? "(none)" : v.joined(separator: ", ")
        }
    }
}

// MARK: - Single reading

/// One named observation emitted by a sensor.
public struct SensorReading: Codable, Sendable, Equatable, Hashable, Identifiable {
    /// Unique identity for SwiftUI use — derived from the key.
    public var id: String { key }
    /// Machine key used in rule matching, e.g. "ssid", "bssid", "connected".
    public let key: String
    /// Human-readable label for display, e.g. "Connected SSID".
    public let label: String
    public let value: ObservationValue

    public init(key: String, label: String, value: ObservationValue) {
        self.key = key
        self.label = label
        self.value = value
    }
}

// MARK: - Sensor snapshot

/// All readings from one sensor captured at a single point in time.
public struct SensorSnapshot: Codable, Sendable {
    public let sensorID: String
    public let displayName: String
    public let readings: [SensorReading]
    public let capturedAt: Date
    /// False if the sensor failed to start or is not applicable to this system.
    public let isActive: Bool

    public init(
        sensorID: String,
        displayName: String,
        readings: [SensorReading],
        capturedAt: Date = Date(),
        isActive: Bool
    ) {
        self.sensorID = sensorID
        self.displayName = displayName
        self.readings = readings
        self.capturedAt = capturedAt
        self.isActive = isActive
    }
}

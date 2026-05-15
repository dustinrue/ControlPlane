import Foundation

// MARK: - Option value

/// A typed value for a sensor configuration option.
public enum SensorOptionValue: Sendable, Equatable {
    case bool(Bool)
    case string(String)
    case number(Double)
}

extension SensorOptionValue: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "bool":   self = .bool(try c.decode(Bool.self, forKey: .value))
        case "string": self = .string(try c.decode(String.self, forKey: .value))
        case "number": self = .number(try c.decode(Double.self, forKey: .value))
        default: throw DecodingError.dataCorruptedError(
            forKey: .type, in: c, debugDescription: "Unknown SensorOptionValue type"
        )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bool(let v):   try c.encode("bool",   forKey: .type); try c.encode(v, forKey: .value)
        case .string(let v): try c.encode("string", forKey: .type); try c.encode(v, forKey: .value)
        case .number(let v): try c.encode("number", forKey: .type); try c.encode(v, forKey: .value)
        }
    }
}

extension SensorOptionValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bool(let v):   return v ? "true" : "false"
        case .string(let v): return v
        case .number(let v): return v.truncatingRemainder(dividingBy: 1) == 0
                                    ? String(Int(v)) : String(format: "%.4g", v)
        }
    }
}

// MARK: - Option descriptor

/// Describes one configurable option exposed by a sensor.
public struct SensorOptionDescriptor: Codable, Sendable {
    /// The key used in set/get calls.
    public let key: String
    /// Human-readable label.
    public let label: String
    /// Short description of what the option does.
    public let description: String
    /// Current value.
    public let value: SensorOptionValue

    public init(key: String, label: String, description: String, value: SensorOptionValue) {
        self.key = key
        self.label = label
        self.description = description
        self.value = value
    }
}

// MARK: - Protocol

/// Sensor plugins that expose runtime-configurable options conform to this protocol.
/// Options are persisted across backend restarts by the SensorConfigStore.
public protocol ConfigurableSensor: SensorPlugin {
    /// Returns descriptors for all supported options with their current values.
    func options() -> [SensorOptionDescriptor]

    /// Apply a single option change. Throw CPError.invalidData if the key or value type
    /// is not recognised.
    func setOption(key: String, value: SensorOptionValue) throws
}

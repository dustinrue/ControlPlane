import Foundation
import ControlPlaneSDK

/// The built-in evaluator plugin. Always registered at backend startup.
///
/// Supports standard comparison operators across all ObservationValue types.
public final class DefaultEvaluator: NSObject, EvaluatorPlugin {
    public let pluginIdentifier  = "com.controlplane.evaluator.basic"
    public let pluginDisplayName = "Basic Evaluator"
    public let pluginVersion     = "1.0.0"
    public let pluginCategory    = "evaluator"

    public override init() { super.init() }

    public static func isApplicable() -> Bool { true }

    // MARK: - EvaluatorPlugin

    public func evaluate(
        reading: ObservationValue?,
        operatorID: String,
        comparand: ObservationValue
    ) -> Bool {
        switch operatorID {
        case "equals":              return equals(reading, comparand)
        case "notEquals":           return !equals(reading, comparand)
        case "greaterThan":         return compare(reading, comparand) == .orderedDescending
        case "lessThan":            return compare(reading, comparand) == .orderedAscending
        case "greaterThanOrEqual":  return compare(reading, comparand) != .orderedAscending
        case "lessThanOrEqual":     return compare(reading, comparand) != .orderedDescending
        case "contains":            return contains(reading, comparand)
        case "notContains":         return !contains(reading, comparand)
        case "startsWith":          return startsWith(reading, comparand)
        case "endsWith":            return endsWith(reading, comparand)
        case "isTrue":              return reading == .boolean(true)
        case "isFalse":             return reading == .boolean(false)
        default:                    return false
        }
    }

    public func supportedOperators() -> [OperatorDescriptor] {
        [
            OperatorDescriptor(id: "equals",             label: "=",                applicableTypes: ["string", "boolean", "number", "strings"]),
            OperatorDescriptor(id: "notEquals",          label: "≠",                applicableTypes: ["string", "boolean", "number", "strings"]),
            OperatorDescriptor(id: "greaterThan",        label: ">",                applicableTypes: ["number", "string"]),
            OperatorDescriptor(id: "lessThan",           label: "<",                applicableTypes: ["number", "string"]),
            OperatorDescriptor(id: "greaterThanOrEqual", label: "≥",                applicableTypes: ["number", "string"]),
            OperatorDescriptor(id: "lessThanOrEqual",    label: "≤",                applicableTypes: ["number", "string"]),
            OperatorDescriptor(id: "contains",           label: "contains",         applicableTypes: ["string", "strings"]),
            OperatorDescriptor(id: "notContains",        label: "does not contain", applicableTypes: ["string", "strings"]),
            OperatorDescriptor(id: "startsWith",         label: "starts with",      applicableTypes: ["string"]),
            OperatorDescriptor(id: "endsWith",           label: "ends with",        applicableTypes: ["string"]),
            OperatorDescriptor(id: "isTrue",             label: "is true",          applicableTypes: ["boolean"]),
            OperatorDescriptor(id: "isFalse",            label: "is false",         applicableTypes: ["boolean"]),
        ]
    }

    // MARK: - Helpers

    private func equals(_ lhs: ObservationValue?, _ rhs: ObservationValue) -> Bool {
        guard let lhs else { return false }
        return lhs == rhs
    }

    private func compare(_ lhs: ObservationValue?, _ rhs: ObservationValue) -> ComparisonResult {
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)):
            return a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
        case (.string(let a), .string(let b)):
            return a.compare(b)
        default:
            return .orderedSame
        }
    }

    private func contains(_ lhs: ObservationValue?, _ rhs: ObservationValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let haystack), .string(let needle)):
            return haystack.contains(needle)
        case (.strings(let arr), .string(let needle)):
            return arr.contains(needle)
        default:
            return false
        }
    }

    private func startsWith(_ lhs: ObservationValue?, _ rhs: ObservationValue) -> Bool {
        guard case .string(let a) = lhs, case .string(let b) = rhs else { return false }
        return a.hasPrefix(b)
    }

    private func endsWith(_ lhs: ObservationValue?, _ rhs: ObservationValue) -> Bool {
        guard case .string(let a) = lhs, case .string(let b) = rhs else { return false }
        return a.hasSuffix(b)
    }
}

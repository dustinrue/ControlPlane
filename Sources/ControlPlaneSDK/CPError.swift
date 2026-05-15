import Foundation

public enum CPError: LocalizedError, Sendable {
    case profileNotFound(UUID)
    case ruleNotFound(UUID)
    case evaluatorNotFound(String)
    case invalidData(String)
    case xpcUnavailable
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .profileNotFound(let id):    return "Profile not found: \(id.uuidString)"
        case .ruleNotFound(let id):       return "Rule not found: \(id.uuidString)"
        case .evaluatorNotFound(let id):  return "Evaluator not loaded: \(id)"
        case .invalidData(let msg):       return "Invalid data: \(msg)"
        case .xpcUnavailable:             return "Could not connect to ControlPlane backend. Is it running?"
        case .notImplemented(let msg):    return "Not yet implemented: \(msg)"
        }
    }
}

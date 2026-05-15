import Foundation
import ControlPlaneSDK
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Connects to the ControlPlane backend over the Unix domain socket and
/// dispatches JSON requests using the CPRequest/CPResponse wire protocol.
///
/// Each logical call opens a dedicated socket connection and closes it when
/// done. This makes the client safe for concurrent async-let usage (multiple
/// callers in the same command) without any locking.
final class XPCClient {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {}

    // MARK: - Profile CRUD

    func createProfile(name: String, parentID: UUID? = nil, exclusive: Bool = false) async throws -> Profile {
        let req = ProfileCreateRequest(name: name, parentID: parentID, exclusive: exclusive)
        return try await send(method: "profileCreate", body: req)
    }

    func getProfile(id: UUID) async throws -> Profile {
        return try await send(method: "profileGet", string1: id.uuidString)
    }

    func updateProfile(id: UUID, name: String, parentID: UUID?, exclusive: Bool) async throws -> Profile {
        let req = ProfileUpdateRequest(name: name, parentID: parentID, exclusive: exclusive)
        return try await send(method: "profileUpdate", string1: id.uuidString, body: req)
    }

    func deleteProfile(id: UUID) async throws {
        try await sendVoid(method: "profileDelete", string1: id.uuidString)
    }

    /// Accepts either a UUID string or a profile name. Names are matched case-sensitively.
    func resolveProfile(_ nameOrUUID: String) async throws -> Profile {
        if let uuid = UUID(uuidString: nameOrUUID) {
            return try await getProfile(id: uuid)
        }
        let all = try await listProfiles()
        let matches = all.filter { $0.name == nameOrUUID }
        switch matches.count {
        case 0: throw CPError.invalidData("No profile found with name '\(nameOrUUID)'")
        case 1: return matches[0]
        default: throw CPError.invalidData("Multiple profiles match '\(nameOrUUID)' — use a UUID to disambiguate")
        }
    }

    func listProfiles() async throws -> [Profile] {
        return try await sendList(method: "profileList")
    }

    // MARK: - Backend status

    func getStatus() async throws -> BackendStatus {
        return try await send(method: "statusGet")
    }

    // MARK: - Plugin inventory

    func listPlugins() async throws -> [PluginInfo] {
        return try await sendList(method: "pluginList")
    }

    // MARK: - Sensor readings

    func listSensorReadings() async throws -> [SensorSnapshot] {
        return try await sendList(method: "sensorListReadings")
    }

    func getSensorReadings(id: String) async throws -> SensorSnapshot {
        return try await send(method: "sensorGetReadings", string1: id)
    }

    func getSensorOptions(id: String) async throws -> [SensorOptionDescriptor] {
        return try await sendList(method: "sensorGetOptions", string1: id)
    }

    func setSensorOption(id: String, key: String, value: SensorOptionValue) async throws {
        try await sendVoid(method: "sensorSetOption", string1: id, string2: key, body: value)
    }

    // MARK: - Profile action CRUD

    func createProfileAction(
        profileID: UUID,
        actionPluginID: String,
        trigger: ActionTrigger,
        config: [String: String] = [:]
    ) async throws -> ProfileAction {
        let req = ProfileActionCreateRequest(profileID: profileID, actionPluginID: actionPluginID, trigger: trigger, config: config)
        return try await send(method: "profileActionCreate", body: req)
    }

    func getProfileAction(id: UUID) async throws -> ProfileAction {
        return try await send(method: "profileActionGet", string1: id.uuidString)
    }

    func updateProfileAction(id: UUID, actionPluginID: String, trigger: ActionTrigger, config: [String: String], enabled: Bool) async throws -> ProfileAction {
        let req = ProfileActionUpdateRequest(actionPluginID: actionPluginID, trigger: trigger, config: config, enabled: enabled)
        return try await send(method: "profileActionUpdate", string1: id.uuidString, body: req)
    }

    func deleteProfileAction(id: UUID) async throws {
        try await sendVoid(method: "profileActionDelete", string1: id.uuidString)
    }

    func listProfileActions(forProfile profileID: UUID) async throws -> [ProfileAction] {
        return try await sendList(method: "profileActionList", string1: profileID.uuidString)
    }

    func listActionTypes() async throws -> [ActionTypeInfo] {
        return try await sendList(method: "actionTypeList")
    }

    /// Run a stored action immediately regardless of profile activation state.
    /// - Parameters:
    ///   - id: The `ProfileAction` UUID.
    ///   - trigger: Override the trigger; nil uses the action's stored trigger.
    func runProfileAction(id: UUID, trigger: ActionTrigger? = nil) async throws {
        try await sendVoid(method: "profileActionRun", string1: id.uuidString, string2: trigger?.rawValue)
    }

    // MARK: - Rule CRUD

    func createRule(
        name: String,
        profileID: UUID,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String = "com.controlplane.evaluator.basic",
        weight: Double = 1.0,
        negate: Bool = false
    ) async throws -> Rule {
        let req = RuleCreateRequest(
            name: name, profileID: profileID, sensorID: sensorID,
            readingKey: readingKey, operatorID: operatorID, comparand: comparand,
            evaluatorID: evaluatorID, weight: weight, negate: negate
        )
        return try await send(method: "ruleCreate", body: req)
    }

    func getRule(id: UUID) async throws -> Rule {
        return try await send(method: "ruleGet", string1: id.uuidString)
    }

    func updateRule(
        id: UUID,
        name: String,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String,
        weight: Double,
        negate: Bool,
        enabled: Bool
    ) async throws -> Rule {
        let req = RuleUpdateRequest(
            name: name, sensorID: sensorID, readingKey: readingKey,
            operatorID: operatorID, comparand: comparand,
            evaluatorID: evaluatorID, weight: weight, negate: negate, enabled: enabled
        )
        return try await send(method: "ruleUpdate", string1: id.uuidString, body: req)
    }

    func deleteRule(id: UUID) async throws {
        try await sendVoid(method: "ruleDelete", string1: id.uuidString)
    }

    func listRules() async throws -> [Rule] {
        return try await sendList(method: "ruleList")
    }

    func listRules(forProfile profileID: UUID) async throws -> [Rule] {
        return try await sendList(method: "ruleListForProfile", string1: profileID.uuidString)
    }

    // MARK: - Evaluator inventory

    func listEvaluators() async throws -> [EvaluatorInfo] {
        return try await sendList(method: "evaluatorList")
    }

    // MARK: - Active profiles

    func listActiveProfiles() async throws -> [ActiveProfile] {
        return try await sendList(method: "activeProfileList")
    }

    // MARK: - Rule match status

    /// Returns a map of rule UUID string → whether it matched in the last evaluation.
    func ruleMatchStatus() async throws -> [String: Bool] {
        return try await send(method: "ruleMatchStatus")
    }

    // MARK: - Private socket helpers

    /// Open a fresh socket connection to the backend.
    /// Returns the connected fd; caller must close it when done.
    private func openSocket() throws -> Int32 {
        let newFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard newFd >= 0 else { throw CPError.xpcUnavailable }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = CPSocketPath
        let sunPathSize = MemoryLayout.size(ofValue: addr.sun_path)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cStr in
                let dest = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                _ = strlcpy(dest, cStr, sunPathSize)
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Foundation.connect(newFd, sa, addrLen)
            }
        }

        guard result == 0 else {
            close(newFd)
            throw CPError.xpcUnavailable
        }

        return newFd
    }

    /// Send one request and decode the response body as `T`.
    /// Opens and closes its own socket connection.
    private func request<T: Decodable>(
        method: String,
        string1: String? = nil,
        string2: String? = nil,
        bodyData: Data? = nil
    ) throws -> T {
        let fd = try openSocket()
        defer { close(fd) }

        let req   = CPRequest(method: method, string1: string1, string2: string2, body: bodyData)
        let frame = try frameMessage(req)
        guard writeAll(fd: fd, data: frame)          else { throw CPError.xpcUnavailable }
        guard let raw = readMessage(fd: fd)          else { throw CPError.xpcUnavailable }
        let resp  = try JSONDecoder().decode(CPResponse.self, from: raw)
        if let err = resp.error                      { throw CPError.invalidData(err) }
        guard let data = resp.data                   else { throw CPError.invalidData("Empty response from backend") }
        return try decoder.decode(T.self, from: data)
    }

    /// Send one void request (no response data expected).
    /// Opens and closes its own socket connection.
    private func requestVoid(
        method: String,
        string1: String? = nil,
        string2: String? = nil,
        bodyData: Data? = nil
    ) throws {
        let fd = try openSocket()
        defer { close(fd) }

        let req   = CPRequest(method: method, string1: string1, string2: string2, body: bodyData)
        let frame = try frameMessage(req)
        guard writeAll(fd: fd, data: frame)          else { throw CPError.xpcUnavailable }
        guard let raw = readMessage(fd: fd)          else { throw CPError.xpcUnavailable }
        let resp  = try JSONDecoder().decode(CPResponse.self, from: raw)
        if let err = resp.error                      { throw CPError.invalidData(err) }
    }

    // MARK: - Async wrappers

    private func send<T: Decodable>(
        method: String, string1: String? = nil, string2: String? = nil
    ) async throws -> T {
        try request(method: method, string1: string1, string2: string2)
    }

    private func send<T: Decodable, B: Encodable>(
        method: String, string1: String? = nil, string2: String? = nil, body: B
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        return try request(method: method, string1: string1, string2: string2, bodyData: bodyData)
    }

    private func sendList<T: Decodable>(
        method: String, string1: String? = nil, string2: String? = nil
    ) async throws -> [T] {
        try request(method: method, string1: string1, string2: string2)
    }

    private func sendVoid(
        method: String, string1: String? = nil, string2: String? = nil
    ) async throws {
        try requestVoid(method: method, string1: string1, string2: string2)
    }

    private func sendVoid<B: Encodable>(
        method: String, string1: String? = nil, string2: String? = nil, body: B
    ) async throws {
        let bodyData = try encoder.encode(body)
        try requestVoid(method: method, string1: string1, string2: string2, bodyData: bodyData)
    }
}

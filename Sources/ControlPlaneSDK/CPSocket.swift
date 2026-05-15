import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Socket path

/// Unix domain socket the app creates; cpctl connects to the same path.
public var CPSocketPath: String {
    let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return appSupport
        .appendingPathComponent("ControlPlane/cpctl.sock")
        .path
}

// MARK: - Wire types

/// A request sent from cpctl → app.
public struct CPRequest: Codable, Sendable {
    public let id: String       // UUID string — echoed in the matching response
    public let method: String   // e.g. "profileList", "ruleCreate"
    public let string1: String? // first positional string param (id, profileID, …)
    public let string2: String? // second positional string param (option key)
    public let body: Data?      // JSON-encoded method payload (base64 in outer JSON)

    public init(
        id: String = UUID().uuidString,
        method: String,
        string1: String? = nil,
        string2: String? = nil,
        body: Data? = nil
    ) {
        self.id      = id
        self.method  = method
        self.string1 = string1
        self.string2 = string2
        self.body    = body
    }
}

/// A response sent from app → cpctl.
public struct CPResponse: Codable, Sendable {
    public let id: String
    public let data: Data?    // JSON-encoded result (base64 in outer JSON)
    public let error: String? // localised error string, or nil on success

    public init(id: String, data: Data? = nil, error: String? = nil) {
        self.id    = id
        self.data  = data
        self.error = error
    }
}

// MARK: - Message framing  (4-byte big-endian length + JSON body)

/// Encodes a Codable value into a length-prefixed frame ready for the wire.
public func frameMessage<T: Encodable>(_ value: T) throws -> Data {
    let json = try JSONEncoder().encode(value)
    var len  = UInt32(json.count).bigEndian
    var msg  = Data(bytes: &len, count: 4)
    msg.append(json)
    return msg
}

/// Reads one length-prefixed frame from `fd`. Returns nil on EOF or error.
/// Blocks the calling thread — invoke from a background thread.
public func readMessage(fd: Int32) -> Data? {
    var lenBuf = [UInt8](repeating: 0, count: 4)
    guard readFully(fd: fd, into: &lenBuf, count: 4) else { return nil }
    let len = Int(UInt32(bigEndian: lenBuf.withUnsafeBytes { $0.load(as: UInt32.self) }))
    guard len > 0 && len < 64 * 1024 * 1024 else { return nil }
    var body = [UInt8](repeating: 0, count: len)
    guard readFully(fd: fd, into: &body, count: len) else { return nil }
    return Data(body)
}

/// Writes all bytes of `data` to `fd`. Returns false on error.
public func writeAll(fd: Int32, data: Data) -> Bool {
    var written = 0
    while written < data.count {
        let n = data.withUnsafeBytes { ptr in
            write(fd, ptr.baseAddress!.advanced(by: written), data.count - written)
        }
        if n <= 0 { return false }
        written += n
    }
    return true
}

// MARK: - Private helpers

private func readFully(fd: Int32, into buf: inout [UInt8], count: Int) -> Bool {
    var total = 0
    while total < count {
        let n = read(fd, &buf[total], count - total)
        if n <= 0 { return false }
        total += n
    }
    return true
}

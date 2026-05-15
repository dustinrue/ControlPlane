import Foundation

/// Convenience base class for action plugins.
///
/// Subclasses must override:
///   - `pluginIdentifier`
///   - `pluginDisplayName`
///   - `pluginVersion`
///   - `execute(trigger:profile:config:)`
///   - `configurationDescriptors()`
///
/// `pluginCategory` is fixed to `"action"` and must not be overridden.
open class BaseAction: NSObject, ActionPlugin {

    // MARK: - ControlPlanePlugin

    open var pluginIdentifier: String {
        fatalError("\(type(of: self)) must override pluginIdentifier")
    }

    open var pluginDisplayName: String {
        fatalError("\(type(of: self)) must override pluginDisplayName")
    }

    open var pluginVersion: String { "1.0.0" }

    /// Fixed — do not override.
    public final var pluginCategory: String { "action" }

    // MARK: - ActionPlugin

    open func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        fatalError("\(type(of: self)) must override execute(trigger:profile:config:)")
    }

    open func configurationDescriptors() -> [ActionConfigDescriptor] {
        fatalError("\(type(of: self)) must override configurationDescriptors()")
    }

    // MARK: - Applicability

    /// Returns `true` if this action can run on the current system.
    /// Override to restrict availability (e.g. OS version checks).
    open class func isApplicable() -> Bool { true }

    // MARK: - Process helper

    /// Runs an executable and returns its stdout as a String.
    /// Throws if the process exits with a non-zero status.
    @discardableResult
    public func runProcess(
        executable: String,
        arguments: [String] = []
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError  = FileHandle.nullDevice

            process.terminationHandler = { p in
                let data   = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if p.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: BaseActionError.processFailed(
                        executable: executable,
                        status: p.terminationStatus,
                        output: output
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

public enum BaseActionError: LocalizedError {
    case processFailed(executable: String, status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .processFailed(let exe, let status, let output):
            return "\(exe) exited with status \(status): \(output)"
        }
    }
}

import Foundation
import ControlPlaneSDK
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Listens on a Unix domain socket and dispatches JSON requests to RequestHandler.
final class SocketServer {
    private let socketPath: String
    private let handler: RequestHandler
    private var serverFd: Int32 = -1

    init(handler: RequestHandler) {
        self.handler    = handler
        self.socketPath = CPSocketPath
    }

    func start() {
        // Remove any stale socket file from a previous run.
        unlink(socketPath)

        serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFd >= 0 else {
            log("SocketServer: socket() failed (errno \(errno))")
            return
        }

        // Bind to the socket path.
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let sunPathSize = MemoryLayout.size(ofValue: addr.sun_path)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            socketPath.withCString { cStr in
                let dest = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                _ = strlcpy(dest, cStr, sunPathSize)
            }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(serverFd, sa, addrLen)
            }
        }
        guard bound == 0 else {
            log("SocketServer: bind() failed (errno \(errno))")
            close(serverFd)
            return
        }

        listen(serverFd, 10)
        log("SocketServer: listening at \(socketPath)")

        // Accept loop on a dedicated background thread — accept(2) blocks.
        let capFd = serverFd
        Thread.detachNewThread { [weak self] in
            self?.acceptLoop(serverFd: capFd)
        }
    }

    func stop() {
        if serverFd >= 0 { close(serverFd); serverFd = -1 }
        unlink(socketPath)
    }

    // MARK: - Private

    private func acceptLoop(serverFd: Int32) {
        while true {
            let clientFd = accept(serverFd, nil, nil)
            if clientFd < 0 { break }
            Task.detached { [weak self] in
                await self?.serve(clientFd: clientFd)
            }
        }
    }

    private func serve(clientFd: Int32) async {
        defer { close(clientFd) }
        let dec = JSONDecoder()

        while true {
            // readMessage blocks; call from async context is acceptable for a
            // low-throughput CLI tool (one request/response per cpctl invocation).
            guard let raw = readMessage(fd: clientFd) else { break }

            let req: CPRequest
            do {
                req = try dec.decode(CPRequest.self, from: raw)
            } catch {
                log("SocketServer: malformed request — \(error)")
                break
            }

            let response = await handler.handle(req)

            do {
                let frame = try frameMessage(response)
                if !writeAll(fd: clientFd, data: frame) { break }
            } catch {
                log("SocketServer: failed to encode response — \(error)")
                break
            }
        }
    }
}

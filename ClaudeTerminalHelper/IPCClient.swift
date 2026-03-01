import Foundation
import Shared

/// Sends AgentEvent to the main app via Unix domain socket.
///
/// The socket path must match HookIPCServer's socket path.
/// Connection is fire-and-forget: if the app is not running, the event is dropped.
final class IPCClient: @unchecked Sendable {
    private var socketPath: String {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        return appSupport
            .appendingPathComponent("ClaudeTerminal")
            .appendingPathComponent("hooks.sock")
            .path
    }

    /// Sends an event and blocks until the app writes a 1-byte response.
    ///
    /// Returns 1 if approved, 0 if rejected or on any error.
    /// Uses a 5-minute socket receive timeout so the helper never hangs indefinitely.
    func sendAndAwaitResponse(event: AgentEvent) -> UInt8 {
        guard let data = try? JSONEncoder().encode(event) else { return 0 }

        let sockfd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockfd >= 0 else { return 0 }
        defer { close(sockfd) }

        var timeout = timeval(tv_sec: 300, tv_usec: 0)
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let path = socketPath
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let sunPathSize = MemoryLayout.size(ofValue: addr.sun_path)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cstr in
                strlcpy(UnsafeMutableRawPointer(ptr)
                    .assumingMemoryBound(to: CChar.self),
                    cstr,
                    sunPathSize)
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(sockfd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else { return 0 }

        var length = UInt32(data.count).bigEndian
        _ = withUnsafeBytes(of: &length) { write(sockfd, $0.baseAddress, 4) }
        _ = data.withUnsafeBytes { write(sockfd, $0.baseAddress, data.count) }

        var response: UInt8 = 0
        _ = read(sockfd, &response, 1)
        return response
    }

    func send(event: AgentEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }

        let sockfd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockfd >= 0 else { return }
        defer { close(sockfd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let path = socketPath
        let sunPathSize = MemoryLayout.size(ofValue: addr.sun_path)  // pre-compute: avoids overlapping access in Swift 6
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cstr in
                strlcpy(UnsafeMutableRawPointer(ptr)
                    .assumingMemoryBound(to: CChar.self),
                    cstr,
                    sunPathSize)
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(sockfd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else { return }

        // Send length-prefixed data
        var length = UInt32(data.count).bigEndian
        _ = withUnsafeBytes(of: &length) { write(sockfd, $0.baseAddress, 4) }
        _ = data.withUnsafeBytes { write(sockfd, $0.baseAddress, data.count) }
    }
}

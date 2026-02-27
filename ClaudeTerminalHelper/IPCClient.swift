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

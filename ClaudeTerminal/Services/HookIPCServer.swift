import Foundation
import Shared

/// Unix domain socket server that receives AgentEvents from ClaudeTerminalHelper.
///
/// The helper connects to this socket for each hook invocation and sends a
/// length-prefixed JSON payload. The server reads, decodes, and forwards to SessionManager.
actor HookIPCServer {
    static let shared = HookIPCServer()

    private var isRunning = false
    private var serverFD: Int32 = -1

    private var socketPath: String {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let dir = appSupport.appendingPathComponent("ClaudeTerminal")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hooks.sock").path
    }

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        Task.detached(priority: .background) { [weak self] in
            await self?.runServer()
        }
    }

    func stop() {
        isRunning = false
        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    // MARK: - Server loop

    private func runServer() async {
        let path = socketPath

        // Remove stale socket if exists
        try? FileManager.default.removeItem(atPath: path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        serverFD = fd

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cstr in
                strlcpy(UnsafeMutableRawPointer(ptr)
                    .assumingMemoryBound(to: CChar.self),
                    cstr,
                    MemoryLayout.size(ofValue: addr.sun_path))
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else { return }

        // Restrict socket to current user only
        chmod(path, 0o600)

        guard listen(fd, 10) == 0 else { return }

        while isRunning {
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else { continue }

            // Read and process in a background task to not block the accept loop
            Task.detached(priority: .background) { [weak self] in
                defer { close(clientFD) }
                await self?.handleConnection(clientFD: clientFD)
            }
        }
    }

    private func handleConnection(clientFD: Int32) async {
        // Read 4-byte big-endian length prefix
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        guard read(clientFD, &lengthBytes, 4) == 4 else { return }
        let length = Int(UInt32(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }))

        // Read payload
        var buffer = [UInt8](repeating: 0, count: length)
        guard read(clientFD, &buffer, length) == length else { return }

        let data = Data(buffer)
        guard let event = try? JSONDecoder().decode(AgentEvent.self, from: data) else { return }

        await SessionManager.shared.handleEvent(event)
    }
}

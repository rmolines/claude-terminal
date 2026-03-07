import Foundation
import Shared

/// Unix domain socket server that receives AgentEvents from ClaudeTerminalHelper.
///
/// The accept loop and connection reads run on dedicated Threads (not in actor isolation)
/// to avoid blocking the actor with blocking C calls (accept/read).
/// Actor isolation is only used for state mutations (pendingHITLConnections, serverFD).
actor HookIPCServer {
    static let shared = HookIPCServer()

    private var isRunning = false
    private var serverFD: Int32 = -1

    /// Stores open client file descriptors for in-flight HITL requests.
    /// The fd is kept open until respondHITL writes the approval byte and closes it.
    private var pendingHITLConnections: [String: Int32] = [:]

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
        let path = socketPath
        // Use a Thread (not a Swift concurrency Task) so blocking accept() doesn't
        // hold the actor or starve the cooperative thread pool.
        let thread = Thread { HookIPCServer.shared.acceptLoop(path: path) }
        thread.qualityOfService = .background
        thread.start()
    }

    func stop() {
        isRunning = false
        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    /// Writes a length-prefixed HookResponse JSON to the waiting helper process and closes the fd.
    func respondHITL(sessionID: String, response: HookResponse) {
        guard let fd = pendingHITLConnections.removeValue(forKey: sessionID) else { return }
        guard let data = try? JSONEncoder().encode(response) else { close(fd); return }
        var length = UInt32(data.count).bigEndian
        withUnsafeBytes(of: &length) { _ = write(fd, $0.baseAddress, 4) }
        data.withUnsafeBytes { _ = write(fd, $0.baseAddress, data.count) }
        close(fd)
    }

    // MARK: - Actor-isolated state helpers (called from nonisolated code via Task)

    fileprivate func storeServerFD(_ fd: Int32) {
        serverFD = fd
    }

    fileprivate func storePendingHITL(sessionID: String, fd: Int32) {
        pendingHITLConnections[sessionID] = fd
    }
}

// MARK: - Blocking I/O (nonisolated — runs on dedicated Threads)

extension HookIPCServer {
    /// Blocking accept loop. Runs on a Thread, never on the actor.
    nonisolated fileprivate func acceptLoop(path: String) {
        try? FileManager.default.removeItem(atPath: path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

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

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else { close(fd); return }

        chmod(path, 0o600)
        guard listen(fd, 10) == 0 else { close(fd); return }

        // Store fd on actor so stop() can close it
        Task { await HookIPCServer.shared.storeServerFD(fd) }

        while true {
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else { break }  // fd closed by stop() breaks the loop
            // Each connection gets its own Thread so blocking reads don't block accept
            let t = Thread { HookIPCServer.shared.readConnection(clientFD: clientFD) }
            t.qualityOfService = .background
            t.start()
        }
        close(fd)
    }

    /// Blocking read for one connection. Runs on a Thread, never on the actor.
    nonisolated fileprivate func readConnection(clientFD: Int32) {
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        guard read(clientFD, &lengthBytes, 4) == 4 else {
            close(clientFD)
            return
        }
        let length = Int(UInt32(bigEndian: lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }))

        var buffer = [UInt8](repeating: 0, count: length)
        guard read(clientFD, &buffer, length) == length else {
            close(clientFD)
            return
        }

        let data = Data(buffer)
        guard let event = try? JSONDecoder().decode(AgentEvent.self, from: data) else {
            close(clientFD)
            return
        }

        Task {
            // Store fd BEFORE handleEvent so handleEvent can call respondHITL immediately
            // (e.g. auto-approve for external sessions) and find the fd.
            if event.type == .permissionRequest {
                await HookIPCServer.shared.storePendingHITL(sessionID: event.sessionID, fd: clientFD)
            }
            await SessionManager.shared.handleEvent(event)
            if event.type != .permissionRequest {
                close(clientFD)
            }
            // For permissionRequest: fd is closed by respondHITL (auto-approve or user decision).
        }
    }
}

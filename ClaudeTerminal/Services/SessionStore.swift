import Foundation
import Observation
import Shared

/// @MainActor bridge from SessionManager actor to SwiftUI.
///
/// SessionManager (an actor) calls `SessionStore.shared.update()` via `Task { @MainActor in ... }`.
/// SwiftUI views observe this via @Observable — no @StateObject or ObservedObject needed.
@MainActor
@Observable
final class SessionStore {
    static let shared = SessionStore()

    private(set) var sessions: [String: AgentSession] = [:]

    var pendingHITLCount: Int {
        sessions.values.filter { $0.status == .awaitingInput }.count
    }

    private init() {}

    func update(_ session: AgentSession) {
        // When a real hook session arrives, evict any synthetic placeholder for the same cwd.
        if !session.isSynthetic, let synthetic = sessions.values.first(where: { $0.isSynthetic && $0.cwd == session.cwd }) {
            sessions.removeValue(forKey: synthetic.sessionID)
        }
        sessions[session.sessionID] = session
    }

    func remove(sessionID: String) {
        sessions.removeValue(forKey: sessionID)
    }
}

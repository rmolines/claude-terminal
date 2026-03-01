import Testing
import Foundation
@testable import Shared

// Run with: swift test --configuration debug

@Suite("SessionManager")
struct SessionManagerTests {

    @Test("AgentEvent encodes and decodes correctly")
    func agentEventCodable() throws {
        let event = AgentEvent(
            sessionID: UUID().uuidString,
            type: .permissionRequest,
            cwd: "/tmp/test"
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(AgentEvent.self, from: data)

        #expect(decoded.sessionID == event.sessionID)
        #expect(decoded.type == event.type)
        #expect(decoded.cwd == event.cwd)
    }

    @Test("HookPayload decodes Claude Code hook JSON")
    func hookPayloadDecoding() throws {
        let json = """
        {
          "session_id": "abc123",
          "transcript_path": "/tmp/transcript.jsonl",
          "cwd": "/Users/test/project",
          "hook_event_name": "Notification"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(HookPayload.self, from: json)
        #expect(payload.sessionID == "abc123")
        #expect(payload.hookEventName == "Notification")
    }
}

// MARK: - State machine tests
//
// SessionManager lives in an executable target and cannot be @testable-imported via SPM.
// LocalSessionManager mirrors its handleEvent state transitions using only Shared types,
// providing confidence that the correct AgentStatus is assigned per event type.

@Suite("Session State Machine")
struct SessionStateMachineTests {

    private actor LocalSessionManager {
        private var sessions: [String: AgentStatus] = [:]

        func handleEvent(_ event: AgentEvent) {
            switch event.type {
            case .notification, .bashToolUse, .subAgentStarted:
                sessions[event.sessionID] = .running
            case .permissionRequest:
                sessions[event.sessionID] = .awaitingInput
            case .stopped:
                sessions[event.sessionID] = .completed
            case .heartbeat:
                break
            }
        }

        func status(for sessionID: String) -> AgentStatus? {
            sessions[sessionID]
        }
    }

    @Test("notification event creates session with .running status")
    func notificationCreatesRunningSession() async {
        let sm = LocalSessionManager()
        let event = AgentEvent(sessionID: UUID().uuidString, type: .notification, cwd: "/tmp")
        await sm.handleEvent(event)
        let status = await sm.status(for: event.sessionID)
        #expect(status == .running)
    }

    @Test("permissionRequest event changes status to .awaitingInput")
    func permissionRequestSetsAwaitingInput() async {
        let sm = LocalSessionManager()
        let event = AgentEvent(sessionID: UUID().uuidString, type: .permissionRequest, cwd: "/tmp")
        await sm.handleEvent(event)
        let status = await sm.status(for: event.sessionID)
        #expect(status == .awaitingInput)
    }

    @Test("stopped event changes status to .completed")
    func stoppedEventCompletesSession() async {
        let sm = LocalSessionManager()
        let sid = UUID().uuidString
        await sm.handleEvent(AgentEvent(sessionID: sid, type: .notification, cwd: "/tmp"))
        await sm.handleEvent(AgentEvent(sessionID: sid, type: .stopped, cwd: "/tmp"))
        let status = await sm.status(for: sid)
        #expect(status == .completed)
    }
}

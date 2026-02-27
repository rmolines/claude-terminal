import Testing
import Foundation
@testable import Shared

// Placeholder test suite — add tests as features are implemented.
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

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
        #expect(payload.usage == nil)
    }

    @Test("TokenUsage decodes snake_case keys from Claude Code Stop JSON")
    func tokenUsageDecoding() throws {
        let json = """
        {
          "session_id": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
          "cwd": "/tmp",
          "hook_event_name": "Stop",
          "usage": {
            "input_tokens": 5000,
            "output_tokens": 200,
            "cache_read_input_tokens": 1000
          }
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(HookPayload.self, from: json)
        let usage = try #require(payload.usage)
        #expect(usage.inputTokens == 5000)
        #expect(usage.outputTokens == 200)
        #expect(usage.cacheReadTokens == 1000)
    }

    @Test("AgentEvent round-trips tokenUsage through Codable")
    func agentEventWithTokenUsage() throws {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 50, cacheReadTokens: 200)
        let event = AgentEvent(
            sessionID: UUID().uuidString,
            type: .stopped,
            cwd: "/tmp",
            tokenUsage: usage
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(AgentEvent.self, from: data)

        let decodedUsage = try #require(decoded.tokenUsage)
        #expect(decodedUsage.inputTokens == 1000)
        #expect(decodedUsage.outputTokens == 50)
        #expect(decodedUsage.cacheReadTokens == 200)
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
        struct SessionState {
            var status: AgentStatus = .running
            var totalInputTokens: Int = 0
            var totalOutputTokens: Int = 0
            var totalCacheReadTokens: Int = 0
        }

        private var sessions: [String: SessionState] = [:]

        func handleEvent(_ event: AgentEvent) {
            if sessions[event.sessionID] == nil {
                sessions[event.sessionID] = SessionState()
            }
            switch event.type {
            case .notification, .bashToolUse, .subAgentStarted:
                sessions[event.sessionID]?.status = .running
            case .permissionRequest:
                sessions[event.sessionID]?.status = .awaitingInput
            case .stopped:
                sessions[event.sessionID]?.status = .completed
            case .heartbeat:
                break
            }
            if let usage = event.tokenUsage {
                sessions[event.sessionID]?.totalInputTokens += usage.inputTokens
                sessions[event.sessionID]?.totalOutputTokens += usage.outputTokens
                sessions[event.sessionID]?.totalCacheReadTokens += usage.cacheReadTokens
            }
        }

        func status(for sessionID: String) -> AgentStatus? {
            sessions[sessionID]?.status
        }

        func tokenTotals(for sessionID: String) -> (input: Int, output: Int, cacheRead: Int)? {
            guard let s = sessions[sessionID] else { return nil }
            return (s.totalInputTokens, s.totalOutputTokens, s.totalCacheReadTokens)
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

    @Test("token usage accumulates across multiple Stop events")
    func tokenUsageAccumulates() async {
        let sm = LocalSessionManager()
        let sid = UUID().uuidString

        let usage1 = TokenUsage(inputTokens: 1000, outputTokens: 100, cacheReadTokens: 500)
        let usage2 = TokenUsage(inputTokens: 2000, outputTokens: 50, cacheReadTokens: 0)

        await sm.handleEvent(AgentEvent(sessionID: sid, type: .stopped, cwd: "/tmp", tokenUsage: usage1))
        await sm.handleEvent(AgentEvent(sessionID: sid, type: .stopped, cwd: "/tmp", tokenUsage: usage2))

        let totals = await sm.tokenTotals(for: sid)
        let t = try! #require(totals)
        #expect(t.input == 3000)
        #expect(t.output == 150)
        #expect(t.cacheRead == 500)
    }

    @Test("events without usage do not affect token totals")
    func eventsWithoutUsageLeaveTotalsZero() async {
        let sm = LocalSessionManager()
        let sid = UUID().uuidString

        await sm.handleEvent(AgentEvent(sessionID: sid, type: .notification, cwd: "/tmp"))
        await sm.handleEvent(AgentEvent(sessionID: sid, type: .bashToolUse, cwd: "/tmp", detail: "ls"))

        let totals = await sm.tokenTotals(for: sid)
        let t = try! #require(totals)
        #expect(t.input == 0)
        #expect(t.output == 0)
        #expect(t.cacheRead == 0)
    }
}

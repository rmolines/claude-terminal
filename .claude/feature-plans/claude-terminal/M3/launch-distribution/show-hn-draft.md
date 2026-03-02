# Show HN Draft

**Title:** Show HN: Claude Terminal – Mission Control for Claude Code agent squads (macOS)

**URL:** https://github.com/rmolines/claude-terminal

---

## Post body

I've been using Claude Code as a force-multiplier — running 4–8 parallel agent sessions across different features while I review PRs or write specs. The problem: you end up with a stack of dumb terminal windows, no idea which agent is stuck waiting for HITL approval, and zero aggregate view of what you're spending.

Claude Terminal is a native macOS dashboard I built to fix that.

**What it shows:**

- Per-session status: current skill phase (start-feature → implement → ship-feature), active bash command, sub-agents spawned in the background
- Live token spend per session (and total across all agents), using hook events — not polling
- Menu bar badge that lights up when any agent is blocked on a HITL permission request
- One-click approve/reject without switching windows or finding the right terminal
- Optional raw terminal tab if you want to see the actual Claude Code output

**How it works:**

Claude Code fires hooks at every significant event (`PreToolUse`, `PostToolUse`, `Stop`, etc.). My thin `ClaudeTerminalHelper` binary reads the hook JSON from stdin, forwards it over a Unix domain socket to the main app. Latency is ~2–5µs. The app reconstructs session state as events arrive — no polling, no process scanning.

The initial setup is a single "Set up Hooks" button that writes the hook config to `~/.claude/settings.json` atomically and registers the helper binary.

**Stack details (for the curious):**

- Swift 6.2 + SwiftUI, strict concurrency, `defaultIsolation = MainActor`
- [SecureXPC](https://github.com/trilemma-dev/SecureXPC) for typed app↔helper IPC — identity verified by audit token, not PID (avoids the TOCTOU race that makes PID-based validation exploitable)
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) for PTY rendering — one `DispatchQueue` per terminal instance so 8 simultaneous sessions don't contend on a shared queue
- SwiftData for task/agent persistence
- Notarized DMG, macOS 14+

**What it's not:**

Not an agent orchestrator — it doesn't start or control Claude Code sessions, just observes them via hooks. You still run `claude` yourself in your terminals. Claude Terminal is the control panel, not the engine.

**Download:** https://github.com/rmolines/claude-terminal/releases/latest

Happy to answer questions about the hook architecture, the SecureXPC setup, or the SwiftTerm multi-instance approach.

---

## HN submission checklist

- [ ] Verify latest release DMG link is live before posting
- [ ] Check that "Set up Hooks" flow works end-to-end on a clean machine
- [ ] Post on a weekday, 9–11am ET for best visibility
- [ ] Have repo README and demo GIF ready (already in README)

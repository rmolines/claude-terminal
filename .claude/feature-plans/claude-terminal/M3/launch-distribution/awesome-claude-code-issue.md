# awesome-claude-code Submission Draft

Submit manually at: https://github.com/hesreallyhim/awesome-claude-code/issues/new?template=recommend-resource.yml

> **Note:** The template explicitly blocks `gh` CLI submissions — must be done via the GitHub UI.

---

## Field values to fill in

**Title:** `[Resource]: Claude Terminal`

**Display Name:** Claude Terminal

**Category:** Tooling

**Sub-Category:** Tooling: Orchestrators

**Primary Link:** https://github.com/rmolines/claude-terminal

**Author Name:** rmolines

**Author Link:** https://github.com/rmolines

**License:** MIT

**Description:**
Native macOS dashboard for managing multiple Claude Code agent sessions in parallel. Shows real-time agent status (skill phase, token spend, sub-agents), badges pending HITL requests in the menu bar, and lets you approve or reject without switching windows.

**Validate Claims:**
Clone the repo, download the DMG from Releases, drag to Applications, launch, and click "Set up Hooks" — the dashboard immediately shows any running `claude` session.

**Specific Task(s):**
Run `claude` in any project directory. Open Claude Terminal. You'll see the session appear with live status updates, token cost, and a HITL badge when the agent needs approval.

**Specific Prompt(s):**
"Implement a small feature in this codebase" — Claude Terminal will show the agent's current bash command, token spend, and surface any HITL permission requests.

**Additional Comments:**
Built with Swift 6.2 + SwiftUI. Uses Unix domain socket hooks for ~2-5µs latency. SecureXPC (audit token, not PID) for helper IPC. One DispatchQueue per SwiftTerm instance to avoid UI contention at 4+ parallel sessions. macOS 14+, notarized DMG.

---

## Checklist (all must be checked)

- [x] I have checked that this resource hasn't already been submitted
- [x] It has been over one week since the first public commit to the repo I am recommending
- [x] All provided links are working and publicly accessible
- [x] I do NOT have any other open issues in this repository
- [x] I am primarily composed of human-y stuff and not electrical circuits

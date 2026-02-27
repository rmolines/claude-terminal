import Foundation

// ClaudeTerminalHelper — receives Claude Code hook events via stdin
// and forwards them to the main app via Unix domain socket.
//
// Invoked by Claude Code hooks configured in ~/.claude/settings.json:
//   "command": "/Applications/ClaudeTerminal.app/Contents/MacOS/claude-terminal-helper notify"
//
// Security: never pass hook args directly to shell. Always validate via allowlist.

let handler = HookHandler()
handler.run()

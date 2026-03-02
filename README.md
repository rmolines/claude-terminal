# Claude Terminal

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
![License MIT](https://img.shields.io/badge/license-MIT-blue)

**Mission Control for your Claude Code agent squad.**

Instead of juggling N stacked terminal windows, you get a native macOS dashboard that shows every agent's status in real time, badges pending HITL requests in the menu bar, and lets you approve or reject without breaking focus.

---

<!-- GIF: gravar e salvar como docs/hitl-demo.gif -->
<!-- TODO: Record a screen capture of the HITL approval flow and save it to docs/hitl-demo.gif -->
<!-- Sugestão de roteiro: abrir o app → iniciar um agente → aguardar pedido HITL aparecer no menu bar → clicar badge → aprovar na janela → agente continua -->

---

## Quickstart

1. **Download** the latest `ClaudeTerminal.dmg` from [Releases](https://github.com/rmolines/claude-terminal/releases)
2. **Open** the DMG and drag Claude Terminal to Applications
3. **Launch** Claude Terminal and click **"Set up Hooks"** — done

Claude Code will now report every agent event to the dashboard automatically.

---

## What you see

- **Dashboard** — one row per active Claude Code session: current skill phase, token spend, sub-agents running in background
- **Menu bar badge** — shows count of pending HITL requests; click to open the approval panel
- **HITL panel** — approve or reject agent permission requests without switching windows
- **Token spend** — running cost per session (input / output / cache read), updated live
- **Task backlog** — persistent list of tasks across sessions (SwiftData)

---

## How it works

```
Claude Code hooks
      │  JSON on stdin
      ▼
ClaudeTerminalHelper   (thin notarized CLI)
      │  Unix domain socket  ~2-5µs latency
      ▼
HookIPCServer          (Swift actor)
      │
      ▼
SessionManager         (Swift actor — all mutable state)
      │  @MainActor publish
      ▼
SwiftUI dashboard
```

Hooks write a JSON payload to the helper's stdin. The helper forwards it over a Unix domain socket to the app. No network, no polling — latency is ~2–5µs.

---

## Requirements

- macOS 14 Sonoma or later
- [Claude Code](https://claude.ai/code) installed (`claude` in PATH)

---

## Contributing

Found a bug or have a feature request? [Open an issue](https://github.com/rmolines/claude-terminal/issues).

---

## License

MIT

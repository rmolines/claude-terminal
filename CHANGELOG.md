# Changelog

---

## [feat] README de produto do Claude Terminal — 2026-03-02

**Tipo:** feat
**Tags:** docs, readme, onboarding
**PR:** [#14](https://github.com/rmolines/claude-terminal/pull/14) · **Complexidade:** simples

### O que mudou

README.md agora descreve o Claude Terminal como produto: badges de versão, quickstart de 3 passos
(Download DMG → Open → Install Hooks), lista de features visíveis, diagrama da arquitetura de hooks,
e placeholder para GIF do fluxo HITL. Quem chega no repositório entende o produto imediatamente.

### Detalhes técnicos

- `README.md` — substituído integralmente (template kickstart → produto Claude Terminal)
- `.claude/commands/start-milestone.md` — outer fences migradas para 4 backticks (MD040/MD048)
- `.claude/commands/project-compass.md` — stray fence sem fechamento removida
- 21 erros de markdownlint pré-existentes corrigidos em commands/ e docs

### Impacto

- **Breaking:** Não
- Desbloqueia `launch-distribution` (dependia de readme-demo)

### Arquivos-chave

- `README.md` — novo README de produto

---

## [improvement] Diagrama Mermaid no workflow.md — 2026-03-02

**Tipo:** improvement
**Tags:** docs, workflow, skills
**PR:** [#12](https://github.com/rmolines/claude-terminal/pull/12) · **Complexidade:** simples

### O que mudou

`workflow.md` agora tem um diagrama `stateDiagram-v2` que renderiza no GitHub, mostrando o fluxo completo de skills com transições, loop tático por feature e caminho de orientação via `project-compass`.

### Detalhes técnicos

- `.claude/feature-plans/claude-terminal/workflow.md` — seção `## Diagrama de fluxo` adicionada
- `~/git/claude-kickstart/.claude/rules/workflow.md` — mesmo diagrama propagado

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/feature-plans/claude-terminal/workflow.md`

---

## [feat] Hook pipeline end-to-end — 2026-03-01

**Tipo:** feat
**Tags:** ipc, hitl, swiftui, actor
**PR:** [#3](https://github.com/rmolines/claude-terminal/pull/3) · **Complexidade:** alta

### O que mudou

Eventos de hook do Claude Code agora fluem end-to-end até a UI: o DashboardView exibe sessões ativas em tempo real
e o badge do menu bar reflete pendências HITL. Permissões bloqueiam o agente até o usuário aprovar/rejeitar via notificação macOS.

### Detalhes técnicos

- `SessionStore.swift` (NOVO): bridge `@MainActor @Observable` do actor `SessionManager` para SwiftUI — sem Combine nem polling
- `HookIPCServer`: mantém fd aberto para HITL; `respondHITL()` escreve 1 byte de aprovação/rejeição
- `SessionManager.handleEvent` tornou-se `async`; pusha snapshot para `SessionStore` após cada mutação; dispara `NotificationService` em `permissionRequest`
- `IPCClient.sendAndAwaitResponse()`: bloqueia o helper com `SO_RCVTIMEO` de 5 min até resposta do app
- `HookHandler.run()` retorna `Int32`; exit 0 = allow, exit 2 = block (spec Claude Code)
- `AppDelegate`: inicia servidor no launch; badge reativo via `withObservationTracking`
- `DashboardView`: lista real de sessões com ícones de status e badge "HITL" laranja

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Services/SessionStore.swift` — NOVO
- `ClaudeTerminal/Services/SessionManager.swift`
- `ClaudeTerminal/Services/HookIPCServer.swift`
- `ClaudeTerminalHelper/IPCClient.swift`
- `ClaudeTerminalHelper/HookHandler.swift`
- `ClaudeTerminal/App/AppDelegate.swift`
- `ClaudeTerminal/Features/Dashboard/DashboardView.swift`

---

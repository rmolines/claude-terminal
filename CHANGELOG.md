# Changelog

---

## [fix] HITL popups suprimidos para sessões externas — 2026-03-04

**Tipo:** fix
**Tags:** hitl, hooks, ipc
**PR:** [#33](https://github.com/rmolines/claude-terminal/pull/33) · **Complexidade:** simples

### Problema

O app mostrava popups de aprovação HITL para **qualquer** sessão do Claude Code na
máquina — inclusive sessões abertas no iTerm — porque o hook `PermissionRequest` é
global (`~/.claude/settings.json`).

### Fix aplicado

Sessões iniciadas pelo app recebem `CLAUDE_TERMINAL_MANAGED=1` no ambiente do PTY.
Esse env var propaga via `fork/exec` até o helper. O `SessionManager` só mostra popup
para sessões com `isManagedByApp == true`; sessões externas são auto-aprovadas silenciosamente.

### Arquivos-chave

- `Shared/IPCProtocol.swift` — campo `isManagedByApp: Bool?` em `AgentEvent`
- `ClaudeTerminalHelper/HookHandler.swift` — lê env var e popula campo
- `ClaudeTerminal/Services/SessionManager.swift` — branching HITL por isManagedByApp
- `ClaudeTerminal/Features/Terminal/MainView.swift` — define env var no PTY

---

## [feat] Bet Bowl — quick idea capture + random draw to task — 2026-03-03

**Tipo:** feat
**Tags:** swiftdata, task-backlog, ux
**PR:** [#27](https://github.com/rmolines/claude-terminal/pull/27) · **Complexidade:** média

### O que mudou

Nova section "Bet Bowl" no sidebar de tasks: capture ideias rápidas em um campo, sorteie uma aleatoriamente com o botão [Draw] e converta a bet sorteada em `ClaudeTask` com um clique.

### Detalhes técnicos

- `Bet.swift` — `@Model` com campos `id`, `title`, `notes`, `status` (`draft`/`converted`), `sortOrder`, `convertedTaskID`
- `SchemaV3.swift` — nova versão de schema SwiftData incluindo `Bet.self`; migração lightweight V2→V3 cria tabela do zero
- `AppMigrationPlan.swift` — stage `migrateV2toV3` adicionado à chain V1→V2→V3
- `BetDrawSheet.swift` — sheet de sorteio com ações Convert to Task / Re-draw / Dismiss
- `TaskBacklogView.swift` — Bet Bowl section com `@Query`, inline form `AutoFocusTextField`, botões [+] e [Draw] (desabilitado com < 2 bets)

### Impacto

- **Breaking:** Não — migração automática transparente; stores V2 existentes sobem para V3 no primeiro launch

### Arquivos-chave

- `ClaudeTerminal/Models/Bet.swift`
- `ClaudeTerminal/Models/SchemaV3.swift`
- `ClaudeTerminal/Features/TaskBacklog/BetDrawSheet.swift`
- `ClaudeTerminal/Features/TaskBacklog/TaskBacklogView.swift`

---

## [fix] SwiftData migration crash no boot — 2026-03-02

**Tipo:** fix
**Tags:** swiftdata, migration, crash
**PR:** [#19](https://github.com/rmolines/claude-terminal/pull/19) · **Complexidade:** simples

### Problema

App crashava no boot com `Fatal error: SwiftData.SwiftDataError` na inicialização do `ModelContainer`.
Dois bugs na migration plan V1→V2 introduzida em bc22d7f combinavam para impedir qualquer lançamento em devices com dados existentes.

### Fix aplicado

1. **`SchemaV1.swift`**: renomeado `ClaudeTaskV1`/`ClaudeAgentV1` → `ClaudeTask`/`ClaudeAgent`.
   Os nomes de classe determinam os entity names Core Data — o sufixo V1 criava mismatch com o store em disco.
2. **`ClaudeTask.swift`**: adicionado `= ""` em `var priority: String`.
   Core Data lightweight migration exige `defaultValue` na NSAttributeDescription para popular linhas existentes ao adicionar coluna não-opcional.

### Arquivos-chave

- `ClaudeTerminal/Models/SchemaV1.swift` — entity names corrigidos
- `ClaudeTerminal/Models/ClaudeTask.swift` — default value adicionado

---

## [feat] Skills Registry — 2026-03-02

**Tipo:** feat
**Tags:** dashboard, skills, ux
**PR:** [#15](https://github.com/rmolines/claude-terminal/pull/15) · **Complexidade:** simples

### O que mudou

Botão sparkles na toolbar do Dashboard abre um sheet com todas as skills e slash commands instalados — auto-trigger, globais e do projeto ativo — com busca em tempo real.

### Detalhes técnicos

- `SkillRegistryService`: escaneia `~/.claude/skills/`, `~/.claude/commands/` e `.claude/commands/` de cada sessão ativa; faz parse de frontmatter YAML ou fallback para humanize + primeira linha de prosa
- `SkillRegistryView`: `List` com seções por `SkillKind`, `TextField` de busca, badges coloridos (purple/blue/green)
- Zero mudanças em schema SwiftData, IPCProtocol ou dependências SPM

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Features/SkillRegistry/` — novos (3 arquivos)
- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — botão + sheet

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

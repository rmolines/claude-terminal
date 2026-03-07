# Research: worksession-panel

## Descrição da feature

Overview panel que agrega `AgentSession` + `WorktreeInfo` + `KanbanFeature` por projeto
selecionado numa entidade runtime chamada `WorkSession`. Ordenada por urgência
(`HITL_PENDING > ERROR > RUNNING > DONE > IDLE`) com aprovação de HITL inline no overview.
Substitui o polling fragmentado atual (3 pollers independentes) por um serviço central.

## Arquivos existentes relevantes

### Serviços (leitura + modificação)
- `ClaudeTerminal/Services/SessionManager.swift` — actor central; `approveHITL`/`rejectHITL` já idempotentes; padrão `Task { @MainActor in SessionStore.shared.update() }` a replicar
- `ClaudeTerminal/Services/SessionStore.swift` — bridge `@MainActor @Observable`; `sessions: [String: AgentSession]`; `WorkSessionService` vai observar este para o join
- `ClaudeTerminal/Services/HookIPCServer.swift` — `pendingHITLConnections[sessionID]`; `respondHITL()` escreve 1 byte no fd; não tocar neste serviço
- `ClaudeTerminal/Services/GitStateService.swift` — actor com `worktrees()`, `changedFiles()`, `commitsAhead()`, `currentBranch()`; já existe, reusar
- `ClaudeTerminal/Services/TerminalRegistry.swift` — `@MainActor`; `sendInput([0x31], forCwd:)` para path PTY do HITL
- `ClaudeTerminal/Services/WorkflowUpdateService.swift` — `@MainActor @Observable`; skill state em SwiftData (leitura)

### Views de referência (padrões a seguir)
- `ClaudeTerminal/Features/Worktrees/WorktreesView.swift` — `hasSession()` (linhas 96-100): join worktree↔session via prefix match; **replicar exatamente**
- `ClaudeTerminal/Features/Kanban/BacklogKanbanModels.swift` — `KanbanFeature` struct com status, milestone, branch
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — hierarquia de view por projeto; como terminal paths são selecionados
- `ClaudeTerminal/Features/Skills/WorkflowPhase.swift` — `WorkflowPhase.infer(branch:cwd:)` reutilizável para urgency sorting
- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — controles inline de aprovação; extrair componente para reuso nas rows

### HITL (arquivos ⚠️ com claims ativos de outras worktrees)
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — `@Observable HITLPanelState`; padrão NSPanel sem `rootView =`; `observeSessions()` com `withObservationTracking`
- `ClaudeTerminal/App/AppDelegate.swift` — init de serviços em `applicationDidFinishLaunching`; onde `WorkSessionService.shared.start()` será chamado

### Arquivos a criar (novos)
- `ClaudeTerminal/Services/WorkSessionService.swift` — `@MainActor @Observable` singleton; único poller consolidado
- `ClaudeTerminal/Models/WorkSession.swift` — struct runtime (não `@Model`)
- `ClaudeTerminal/Features/WorkSession/WorkSessionPanelView.swift` — view principal do overview
- `ClaudeTerminal/Features/WorkSession/WorkSessionRowView.swift` — row com inline HITL

## Padrões identificados

### Join worktree↔session
```swift
// De WorktreesView.hasSession() — replicar em WorkSessionService
session.cwd.hasPrefix(worktree.path) || worktree.path.hasPrefix(session.cwd)
```
Handles sessões aninhadas e estados transitórios. `WorkSession.id = worktree.path` (estável);
fallback `session.sessionID` se não houver worktree ainda.

### Actor → @Observable bridge
```swift
// Em métodos do actor SessionManager:
Task { @MainActor in SessionStore.shared.update(session) }
// Views observam SessionStore.shared automaticamente
```
Sem isso, views ficam congeladas — padrão confirmado crítico no MEMORY.md.

### Multi-source join sem `withObservationTracking`
Usar `didSet` em cada source property para disparar o join (não `withObservationTracking` —
issue #83359 do Swift: perde updates concorrentes):
```swift
var gitWorktrees: [WorktreeInfo] = [] { didSet { recomputeWorkSessions() } }
var sessions: [String: AgentSession] = [] { didSet { recomputeWorkSessions() } }
var kanbanFeatures: [KanbanFeature] = [] { didSet { recomputeWorkSessions() } }
var workSessions: [WorkSession] = [] // output derivado
```

### List rows com identidade estável
- `WorkSession.id = worktree.path` (nunca UUID gerado no poll cycle)
- Memoizar em `[String: WorkSession]` interno para evitar flicker
- **Não incluir** `lastUpdate: Date` na equalidade — dispara animation em todo poll

### Buttons inline em List rows (macOS)
```swift
Button("Approve") { ... }
    .buttonStyle(.plain) // CRÍTICO — sem isso, toda a row vira botão
```
Sem `.buttonStyle(.plain)`, SwiftUI extende o tap target para a row inteira e todos os
botões disparam juntos (bug conhecido FB12285575).

### NSPanel + @Observable (para suprimir floating panel ao aprovar inline)
- Usar `@Observable HITLPanelState` compartilhado — nunca `hosting.rootView =`
- Verificar `HITLFloatingPanelController` visibility antes de mostrar inline HITL
- `approveHITL` já é idempotente: ok chamar de ambos os lugares

## Dependências externas

Nenhuma dependência nova de pacotes externos. Reusa:
- `GitStateService` (já existe)
- `KanbanReader` (já existe)
- `SessionStore` / `SessionManager` (já existem)

## Hot files que serão tocados

- `ClaudeTerminal/App/AppDelegate.swift` — adicionar `WorkSessionService.shared.start()` [⚠️ CONFLITO: claimed por `session-cards-hitl-ui`]
- `ClaudeTerminal/Services/SessionManager.swift` — possivelmente só leitura; se precisar expor método → mínima mudança [⚠️ CONFLITO: claimed por `session-cards-hitl-ui`]
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — suprimir panel quando inline ativo [⚠️ CONFLITO: claimed por `session-cards-hitl-ui` + `docs-lifecycle`]

Arquivos criados do zero (sem conflito):
- `WorkSessionService.swift`, `WorkSession.swift`, `WorkSessionPanelView.swift`, `WorkSessionRowView.swift`

## Riscos e restrições

| Risco | Mitigação |
|---|---|
| **3 worktrees ativas com conflito direto** — `session-cards-hitl-ui` toca SessionManager, HITL, AppDelegate, IPCProtocol; `docs-lifecycle` toca HITL | **Aguardar merge dessas branches antes de criar worktree**. Ordem recomendada: `session-restore-install` → `session-cards-hitl-ui` → `docs-lifecycle` → `worksession-panel` |
| Join instável cwd↔path | Replicar `hasSession()` de WorktreesView — prefix match já testado em produção |
| 3 pollers git em paralelo (overhead + race) | `WorkSessionService` assume o polling; views existentes viram consumidoras |
| HITL double-fire (floating panel + inline simultâneos) | `approveHITL` idempotente + suprimir floating panel quando `NSApp.isActive` + inline aprovado |
| Identidade instável de rows (UUID regenerado a cada poll) | `id = worktree.path` (string estável) em vez de UUID gerado no runtime |
| `withObservationTracking` perde updates concorrentes | Usar `didSet` observers em vez de `withObservationTracking` para recompute do join |
| Button tap área em List rows (macOS) | `.buttonStyle(.plain)` obrigatório em todos os botões inline |
| `_postWindowNeedsUpdateConstraints` crash se mudar `rootView =` do NSPanel | Usar padrão `@Observable HITLPanelState` já estabelecido — nunca `rootView =` |

## Urgency sorting implementation

| Tier | Condição de source | Prioridade |
|---|---|---|
| `HITL_PENDING` | `session.status == .awaitingInput` | 0 (mais urgente) |
| `ERROR` | `session.status == .blocked` | 1 |
| `RUNNING` | `session.status == .running` | 2 |
| `DONE` | `session.status == .completed` | 3 |
| `IDLE` | Sem sessão ativa (worktree órfã) | 4 |

Tie-breaker: `session.lastEventAt` (mais recente primeiro).

## Fontes consultadas

- Codebase: leitura direta dos arquivos listados acima
- [Swift Forums: @Observable singleton + @MainActor](https://forums.swift.org/t/swift-6-and-singletons-observable-and-data-races/71101)
- [withObservationTracking issue #83359](https://github.com/swiftlang/swift/issues/83359)
- [Multiple buttons in SwiftUI List rows](https://nilcoalescing.com/blog/MultipleButtonsInListRows/)
- [Swift deinit with Strict Concurrency](https://newsletter.mobileengineer.io/p/swift-deinit-with-strict-concurrency)

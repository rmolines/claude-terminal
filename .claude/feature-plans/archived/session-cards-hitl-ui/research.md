# Research: session-cards-hitl-ui

## Descricao da feature

Dashboard de supervisao de N sessoes Claude Code simultaneas: session cards com identidade
(projeto + worktree/branch + fase + status em tempo real) agrupados por projeto, mais fila
visual de HITLs pendentes com approve/reject sem abrir o terminal.

## Arquivos existentes relevantes

### Core state & protocol
- `Shared/IPCProtocol.swift` — `AgentEvent` (sessionID, type, cwd, timestamp, detail, tokenUsage, isManagedByApp); `AgentStatus` enum (running/awaitingInput/completed/blocked); `HookPayload`
- `Shared/AgentEventType.swift` — notification, permissionRequest, stopped, bashToolUse, subAgentStarted, heartbeat, userPromptSubmit
- `ClaudeTerminal/Services/SessionManager.swift` — actor central; `AgentSession` struct (sessionID, cwd, status, lastEventAt, startedAt, currentActivity: String?, subAgentCount, tokens, recentMessages); `pendingHITLConnections: [String: Int32]`
- `ClaudeTerminal/Services/SessionStore.swift` — `@Observable @MainActor`; `sessions: [String: AgentSession]`; bridge do actor para SwiftUI

### HITL atual (a substituir/evoluir)
- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — VStack simples; mostra UMA aprovacao; width 400, height ~160
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — `@MainActor` NSPanel controller; pega `.first { .awaitingInput }` — so exibe um HITL de cada vez; usa `@Observable HITLPanelState` (reference impl correta para NSPanel)

### Navegacao e UI existente
- `ClaudeTerminal/Features/Terminal/MainView.swift` — NavigationSplitView raiz; sidebar com `ProjectRow` (mostra aggregateStatus: awaiting/running/nil); detalhe mostra ProjectDetailView
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — TabView: Terminal/Skills/Worktrees/Workflow/Kanban
- `ClaudeTerminal/Features/Skills/AgentWorkflowCard.swift` — card de referencia existente: session + branch + fase + next steps
- `ClaudeTerminal/App/AppDelegate.swift` — NSStatusItem (menu bar); `updateBadge(count:)`; notificacoes APPROVE_ACTION/REJECT_ACTION

### Auxiliares
- `ClaudeTerminal/Services/TerminalRegistry.swift` — `sendInput(_:forCwd:)` para PTY injection
- `ClaudeTerminal/Models/ClaudeProject.swift` — `@Model`; `.path`, `.currentSkillID`, `.lastWorkflowUpdate`, `workflowStatesJSON`
- `ClaudeTerminal/Features/Skills/WorkflowPhase.swift` — `WorkflowPhase.infer(branch:cwd:)` — strategic/featureActive/readyToShip/unknown

## Modelo de dados atual relevante

```swift
struct AgentSession: Sendable {
    let sessionID: String
    let cwd: String                        // usado para vincular a ClaudeProject
    var status: AgentStatus                // running | awaitingInput | completed | blocked
    var lastEventAt: Date
    let startedAt: Date                    // base para elapsed time
    var currentActivity: String?           // "$ cmd" | "Sub-agent spawned" | "/skillID" | "Awaiting approval"
    var subAgentCount: Int
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var recentMessages: [String]           // ultimas 3 mensagens de notificacao
    var isSynthetic: Bool
}
```

**Lacunas para os session cards:**
- Sem `toolName` estruturado no evento — `detail` e string generica; para Tier 2 pode ser necessario parsear ou adicionar campo ao `AgentEvent`
- Sem `branch` na session — derivar via `GitStateService.currentBranch(in: cwd)` ou adicionar ao `AgentSession` no SessionStart
- Sem `projectName` — derivar de `cwd` comparando com `ClaudeProject.path` no SessionStore
- Sem `riskLevel` — computar localmente via pattern matching no `currentActivity` / `detail`

## Padroes identificados

- `@Observable` em todo o projeto (nao @StateObject/ObservableObject)
- Actor → Observable bridge: sempre `Task { @MainActor in SessionStore.shared.update(session) }` — sem isso views ficam stale sem erro
- NSPanel: criar uma vez, nunca reatribuir `rootView =`; mutar apenas via `@Observable HITLPanelState`; dimensoes fixas (sem `sizingOptions = [.minSize]`)
- `ForEach + .onTapGesture` para selecao — nao `List(selection:)` com `@Model`
- `TimelineView(.periodic(from: .now, by: 1.0))` no view pai para elapsed time — nao timers individuais por card
- Hierarquia de views: `*View` (SwiftUI), `*Card` (card-like), `*Row` (list item), `*Container` (layout)
- `AgentWorkflowCard.swift` e a referencia de implementacao de card existente no projeto

## Layout recomendado (web research)

Para 4-8 sessoes com agrupamento por projeto:
- `LazyVGrid(columns: [GridItem(.flexible())])` com `Section` headers pineados — melhor que List para card layouts customizados
- Uma `@Observable SessionCardState` por sessao (nao todas num unico objeto) — evita redraw em cascata
- `TimelineView(.periodic)` no container pai, nao por card
- Risk badge via `.overlay(alignment: .topTrailing)` com `Circle` + `Image(systemName:)`

## Dependencias externas

Nenhuma nova dependencia de terceiros.

## Hot files que serao tocados

- `Shared/IPCProtocol.swift` — adicionar `toolName: String?` ao `AgentEvent` para Tier 2 (opcional; pode parsear do `detail` primeiro) [fonte de dados dos cards]
- `ClaudeTerminal/Services/SessionManager.swift` — adicionar campos ao `AgentSession` (`branch`, `projectName`) e popular nos event handlers [estado central]
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — substituir logica single-HITL por queue; passar lista de pendentes para nova HITLQueueView [HITL queue]
- `ClaudeTerminal/Features/Terminal/MainView.swift` — integrar SessionCardsContainerView na navegacao; ou adicionar DashboardView como nova tab/pane [navegacao]
- `ClaudeTerminal/App/AppDelegate.swift` — atualizar badge count se cards moverem para main window [menu bar badge]

## Novos arquivos a criar

```
ClaudeTerminal/Features/SessionCards/
  SessionCardsContainerView.swift   — grid agrupado por projeto com TimelineView pai
  SessionCardView.swift             — card individual: Tier1 + Tier2 + Tier3 expansivel
  SessionCardHeaderView.swift       — status badge + project/branch/phase identity
  HITLQueueView.swift               — lista de approvals pendentes (substitui single modal)
  ApprovalCardView.swift            — card individual de HITL com tool, args, risk surface
  RiskSurfaceComputer.swift         — pattern matching isolado (rm -rf, git push --force, etc.)
```

## Riscos e restricoes

- **Actor → Observable sync silencioso**: toda nova escrita de estado em SessionManager precisa de `Task { @MainActor in SessionStore.shared.update(session) }` — sem isso views ficam stale sem nenhum erro visivel
- **NSPanel geometry crash (macOS 26)**: `hosting.rootView =` enquanto panel visivel, OU `sizingOptions = [.minSize]` + mutacao @Observable — ambos causam `_postWindowNeedsUpdateConstraints` crash. Fix: dimensoes fixas + @Observable state mutations apenas
- **toolName nao estruturado**: `currentActivity` e string generica; para exibir "Bash: rm -rf /tmp/foo" no Tier 2 pode ser necessario parsear ou adicionar `toolName: String?` ao `AgentEvent` no IPCProtocol (mudanca no Shared — afeta tambem o Helper)
- **Branch name na session**: `AgentSession.cwd` esta disponivel mas branch requer query git ou campo adicional; adicionar ao SessionStart via `git branch --show-current` no Helper ou derivar no SessionStore
- **TimelineView em 8 cards**: cada card com timer proprio seria 8 TimelineViews — OK em escala pequena mas padrao recomendado e um unico TimelineView no container pai passando `context.date` via environment ou binding
- **Risk surface calibracao**: false positives treinam ignorar badges; isolado em `RiskSurfaceComputer` para ser evoluido independentemente; comecar conservador (apenas comandos classicamente destrutivos)

## Fontes consultadas

- WWDC25: "What's new in SwiftUI" — `@IncrementalState`, fine-grained updates
- WWDC25: "Optimize SwiftUI performance with Instruments" — profiling dashboards
- WWDC24: "What's new in SwiftUI" — @Observable macOS patterns
- SwiftUI TrozWare 2025: macOS-specific LazyVGrid / List trade-offs
- Apple Developer Docs: TimelineView, LazyVGrid, NSPanel
- Projeto MEMORY.md: NSPanel crash patterns, actor bridge, TimelineView em list rows

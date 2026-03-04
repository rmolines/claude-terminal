# Research: agent-card-ui

## Descrição da feature
Substituir a lista de sessões + split-view do DashboardView por um grid adaptativo de
cards por agente. Cada card mostra: status dot, cwd, contexto derivado de hooks
(último evento relevante), timer, tokens. HITL inline no card (Approve/Deny).
Terminal raw acessível via popover ao clicar no card.

## Arquivos existentes relevantes

- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — layout atual (NavigationSplitView
  3 colunas: TaskBacklog | List SessionRow | AgentTerminalView). Será o principal arquivo mudado.
- `ClaudeTerminal/Features/Dashboard/AgentTerminalView.swift` — reutilizado no popover; spawna
  `/bin/zsh` no cwd da sessão (NÃO é o processo do Claude Code).
- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — componente já existente mas NÃO
  integrado à lista atual. Será embarcado no card.
- `ClaudeTerminal/Services/SessionStore.swift` — `@Observable @MainActor` SessionStore,
  `sessions: [String: AgentSession]`. Views observam via `@Observable` (sem @StateObject).
- `ClaudeTerminal/Services/SessionManager.swift` — actor central; `approveHITL` e
  `rejectHITL` já existem. Nenhuma mudança necessária.
- `Shared/IPCProtocol.swift` — `AgentEvent`, `AgentEventType`, `AgentStatus`. Sem mudanças.
- `Shared/AgentEventType.swift` — events: notification, bashToolUse, subAgentStarted,
  permissionRequest, stopped, heartbeat.

## AgentSession — dados disponíveis por card

```swift
struct AgentSession {
    let sessionID: String
    let cwd: String              // working directory
    var status: AgentStatus      // .running | .awaitingInput | .completed | .blocked
    var currentActivity: String? // já populado de hooks:
                                 //   bashToolUse → "$ cmd"
                                 //   permissionRequest → detail ou "Awaiting approval"
                                 //   subAgentStarted → "Sub-agent spawned"
                                 //   stopped → "Completed"
    var subAgentCount: Int
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var totalCacheReadTokens: Int
    let startedAt: Date
    var lastEventAt: Date
}
```

O `currentActivity` já serve como "contexto derivado de hooks" — não precisa de novo campo.

## Padrões identificados

- `TimelineView(.periodic(from: .now, by: 1.0))` para live updates no SessionRow — manter
- `LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))])` para grid adaptativo
- `.popover()` para terminal (alternativa: `.sheet()` se popover for muito pequeno)
- `Task { await SessionManager.shared.approveHITL(sessionID) }` para botões inline
- Botões HITL de qualquer view `@MainActor` podem chamar `Task { await ... }` diretamente

## Limitação do protocolo HITL (importante)

O `respondHITL(approved: Bool)` envia 1 byte. Só suporta aprovação binária.
As únicas interações que o hook bloqueia são permission requests (PreToolUse) — que são
sempre approve/deny.

"Perguntas" do Claude no output (yes/no, texto livre) **não geram hook events** que
bloqueiam o processo — elas são apenas output de texto no terminal. Portanto:

- **MVP**: botões Approve/Deny no card para permission requests (protocolo atual)
- **Fora do escopo**: respostas de texto livre (exigiria nova modalidade IPC)
- "Yes/No" do card = Approve/Deny renomeados contextualmente quando aplicável

## Dependências externas

Nenhuma. Tudo com SwiftUI nativo + componentes existentes.

## Hot files que serão tocados

- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — mudança principal
- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — integração no card (adaptação menor)

## Conflitos

Nenhum. Worktrees ativas:
- `hook-installer-service` → `SettingsWriter.swift` only
- `skill-workflow-ux` → `.claude/` docs only

## Riscos e restrições

- **Popover + PTY**: `AgentTerminalView` spawna um processo zsh. Ao fechar o popover,
  a view é desalocada e o processo é morto. Comportamento aceitável (é uma shell separada,
  não o Claude Code). Re-abrir recria uma nova shell no mesmo cwd.
- **Stale worktrees**: 5+ worktrees stale abertas. Avisar o usuário no Passo C.3.
- **LazyVGrid reordering**: sessions são `[String: AgentSession]` — dict sem ordem. Usar
  `store.sessions.values.sorted { $0.lastEventAt > $1.lastEventAt }` (já existe).
- **Card size fixo**: height fixa no card evita reflows ao mudar `currentActivity`.

## Fontes consultadas

Leitura direta do codebase. Sem URLs externas necessárias.

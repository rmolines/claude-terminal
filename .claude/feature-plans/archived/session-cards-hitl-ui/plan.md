# Plan: session-cards-hitl-ui

## Problema

O dashboard atual não oferece visibilidade cross-project de N sessões Claude Code simultâneas.
O painel HITL exibe apenas uma aprovação por vez — com múltiplos agentes pendentes,
aprovações se perdem ou exigem alternar manualmente entre projetos.

Objetivo: (1) session cards agrupados por projeto com identidade visual (projeto + branch +
fase WorkflowPhase + status + atividade em tempo real); (2) fila de HITLs pendentes com
approve/reject inline sem abrir terminal.

## Assuncoes

<!-- status: [assumed] = nao verificada | [verified] = confirmada | [invalidated] = refutada -->
<!-- risco:   [blocking] = falsa bloqueia a implementacao | [background] = emerge naturalmente -->

- [assumed][blocking] `session.cwd.hasPrefix(project.path)` e suficiente para vincular sessao a projeto
- [assumed][blocking] `git branch --show-current` em `cwd` retorna branch correta em worktrees
- [assumed][background] `WorkflowPhase.infer(branch:cwd:)` funciona sem mudancas
- [assumed][background] NSPanel 440x360 com ScrollView interno acomoda 1-5 HITL items sem crash

## Questoes abertas

**A implementacao vai responder (monitorar):**

- Overhead de git query async por nova sessao e aceitavel para N=8 sessoes simultaneas?
- Altura fixa 440x360 no panel: suficiente para 4+ items ou precisamos de outro valor?

**Explicitamente fora do escopo:**

- Tier 3 expansivel com historico completo do agente
- Push notifications nativas para HITL (alem do badge existente)
- Sorting/filtering de sessoes no dashboard
- Historico de sessoes completed/blocked

## Deliverables

### Deliverable 1 — Session Cards: enriquecimento de dados + grid visual

**O que faz:** Adiciona `branch` e `toolName` ao pipeline de dados; cria o grid de session
cards agrupado por projeto com status badge, elapsed time, branch, fase e currentActivity;
integra na sidebar do `MainView` como entrada "All Sessions" dedicada.

**Criterio de done:** Com >= 1 sessao ativa, clicar em "All Sessions" na sidebar mostra cards
com nome do projeto, branch (ou "—"), fase WorkflowPhase, status badge colorido, elapsed time
e currentActivity. O TimelineView no container pai atualiza o elapsed time a cada segundo.

**Valida:** assuncao de hasPrefix match para projectName; git query para branch

**Resolve:** "nao tenho visao cross-project de sessoes ativas"

**Deixa aberto:** aprovacoes HITL ainda usam o panel single-item legado

**Execute `/checkpoint` antes de continuar para o Deliverable 2.**

### Deliverable 2 — HITL Queue Panel

**O que faz:** Substitui o single-HITL panel por fila de todos os HITLs pendentes. Cada item
mostra toolName, detail (truncado), risk badge (RiskSurfaceComputer), e botoes Approve/Reject
independentes. O panel persiste enquanto houver >= 1 pendente.

**Criterio de done:** Com 2 sessoes simultaneas em `awaitingInput`, o panel exibe 2
ApprovalCards; clicar Approve em um resolve-o e remove-o da lista sem fechar o panel; o outro
item permanece visivel e acionavel.

**Valida:** assuncao de NSPanel altura fixa para N items

**Resolve:** "aprovacoes se perdem quando ha multiplos agentes pendentes"

## Arquivos a modificar

- `Shared/IPCProtocol.swift` — adicionar `toolName: String?` a `AgentEvent` (init + body)
- `ClaudeTerminalHelper/HookHandler.swift` — passar `payload.toolName` ao construir `AgentEvent`
- `ClaudeTerminal/Services/SessionManager.swift` — adicionar `branch: String?` e `pendingToolName: String?` a `AgentSession`; popular via git query e event.toolName
- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — substituir `HITLPanelState` por versao com lista de items; renomear view para `HITLQueueView`
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — `updatePanel()` coleta todos `awaitingInput`; ajustar panel size para 440x360
- `ClaudeTerminal/Features/Terminal/MainView.swift` — adicionar item "All Sessions" no topo do sidebar; condicional no detail pane

## Novos arquivos

```
ClaudeTerminal/Features/SessionCards/
  RiskSurfaceComputer.swift          — enum RiskLevel + pattern matching isolado
  SessionCardHeaderView.swift        — status badge + project/branch/phase identity
  SessionCardView.swift              — card: header + divider + activity + elapsed
  SessionCardsContainerView.swift    — @Query projects + TimelineView pai + LazyVGrid sections
  ApprovalCardView.swift             — card HITL: tool badge, description, risk, Approve/Reject
```

## Passos de execucao

### Deliverable 1

1. `Shared/IPCProtocol.swift` — adicionar `toolName: String?` a `AgentEvent`:
   campo no body (stored property) + parametro `toolName: String? = nil` no `init`.
   Backward-compatible: opcional com default nil, nenhuma mudanca em decoders existentes.

2. `ClaudeTerminalHelper/HookHandler.swift` — passar `toolName: payload.toolName` ao construir
   `AgentEvent` na linha 59. Apenas para `.permissionRequest` e `.bashToolUse` tem valor
   nao-nil; para outros tipos fica nil silenciosamente.

3. `ClaudeTerminal/Services/SessionManager.swift`:
   - Adicionar `var branch: String? = nil` e `var pendingToolName: String? = nil` a `AgentSession`
   - Em `updateOrCreate`: se `sessions[id] == nil` (sessao nova), lancar `Task.detached` com
     `Process` para `git -C cwd branch --show-current`; ao completar,
     `Task { await self.setBranch(sessionID:branch:) }` (metodo nonisolated-safe do ator)
   - Em `.permissionRequest`: `sessions[event.sessionID]?.pendingToolName = event.toolName`

4. Criar `ClaudeTerminal/Features/SessionCards/RiskSurfaceComputer.swift`:
   ```swift
   enum RiskLevel { case normal, elevated, critical }
   struct RiskSurfaceComputer {
       static func compute(toolName: String?, detail: String?) -> RiskLevel
   }
   ```
   Patterns critical: `rm -rf`, `git push --force`, `DROP TABLE`, `truncate`, `format`
   Patterns elevated: `git push`, `git reset`, `DELETE FROM`, `mv /`, `chmod -R`

5. Criar `ClaudeTerminal/Features/SessionCards/SessionCardHeaderView.swift`:
   - Parametros: `session: AgentSession, projectName: String, now: Date`
   - Status badge (Circle + Text), project name (bold), branch (monospaced caption),
     phase pill (WorkflowPhase.infer), elapsed time (now - session.startedAt)

6. Criar `ClaudeTerminal/Features/SessionCards/SessionCardView.swift`:
   - Parametros: `session: AgentSession, projectName: String, now: Date`
   - Header + Divider + currentActivity (ou "Running..." se nil) + token summary (caption)
   - `.background(.background).clipShape(RoundedRectangle(cornerRadius:8)).overlay(stroke)`
   - Padrao visual identico ao `AgentWorkflowCard`

7. Criar `ClaudeTerminal/Features/SessionCards/SessionCardsContainerView.swift`:
   - `@Query(sort: \ClaudeProject.sortOrder) var projects`
   - `TimelineView(.periodic(from: .now, by: 1.0))` no container pai
   - `ScrollView > LazyVGrid(columns:[GridItem(.flexible())])`
   - Sections por projeto: `ForEach(projectsWithSessions)` com header pinado
   - Sessoes ativas: `sessions.values.filter { !$0.isSynthetic && $0.status != .completed && $0.status != .blocked && $0.cwd.hasPrefix(project.path) }`
   - Estado vazio: `ContentUnavailableView("No active sessions", systemImage:"terminal")`

8. `ClaudeTerminal/Features/Terminal/MainView.swift`:
   - Adicionar `@State private var showDashboard = false` (ou enum para selection)
   - No `List` do sidebar, antes do `ForEach(projects)`, adicionar row "All Sessions"
     com `Image(systemName:"rectangle.grid.2x2")` e badge com count de sessoes ativas
   - No detail pane: `if showDashboard { SessionCardsContainerView() } else { ZStack { ... } }`

9. Build + verificacao de compilacao

**Execute `/checkpoint` — Deliverable 1 concluido.**

### Deliverable 2

10. `ClaudeTerminal/Features/HITL/HITLPanelView.swift`:
    - Adicionar `struct HITLItem` com:
      `sessionID: String, description: String, toolName: String?, riskLevel: RiskLevel,
       onApprove: () -> Void, onReject: () -> Void`
    - Substituir campos de `HITLPanelState` por `var pendingItems: [HITLItem] = []`
    - Criar `HITLQueueView`: `ScrollView > VStack { ForEach(state.pendingItems) { ApprovalCardView } }`
    - `.frame(width: 440, height: 360)` — tamanho fixo, sem sizingOptions = [.minSize]

11. Criar `ClaudeTerminal/Features/SessionCards/ApprovalCardView.swift`:
    - `let item: HITLItem`
    - Header: `RiskBadge(item.riskLevel)` + tool name + session ID abreviado
    - Body: `Text(item.description).lineLimit(3)`
    - Footer: `Button("Reject", role:.destructive) { item.onReject() }` + `Button("Approve") { item.onApprove() }`
    - `.background(.background).clipShape(RoundedRectangle(cornerRadius:8)).overlay(stroke)`

12. `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift`:
    - `updatePanel()`: coletar `sessions.values.filter { $0.status == .awaitingInput }`
    - Popular `panelState.pendingItems` com um `HITLItem` por sessao, incluindo closures de approve/reject
    - `if !panel.isVisible && !pendingItems.isEmpty { panel.center(); panel.makeKeyAndOrderFront(nil) }`
    - `if pendingItems.isEmpty { panel.orderOut(nil) }`
    - Ajustar `makePanel()`: `contentRect: NSRect(x:0, y:0, width:440, height:360)`
    - Atualizar `NSHostingView` para usar `HITLQueueView(state: panelState)` em vez de `HITLPanelView`

13. Build final + verificacao de compilacao

## Checklist de infraestrutura

- [ ] Novo Secret: nao
- [ ] Script de setup: nao
- [ ] CI/CD: nao muda
- [ ] Config principal: nao muda
- [ ] Novas dependencias: nao

## Rollback

```bash
git -C "$(git worktree list | head -1 | awk '{print $1}')" checkout main
git worktree remove .
```

Os arquivos novos estao todos no worktree — remover o worktree desfaz tudo.
Os arquivos modificados (`Shared/IPCProtocol.swift`, etc.) ficam apenas no branch da feature.

## Learnings aplicados

- **Actor -> Observable sync**: toda nova escrita em `SessionManager` que precisa refletir na UI
  termina com `Task { @MainActor in SessionStore.shared.update(session) }` — sem isso views ficam stale
- **NSPanel geometry crash (macOS 26)**: nunca `hosting.rootView =`; usar `@Observable HITLPanelState`;
  view com `.frame(width:height:)` fixo e SEM `sizingOptions = [.minSize]`
- **TimelineView em lista**: um unico `TimelineView(.periodic)` no container pai, passando `context.date`
  para os cards — nao criar timers individuais por card
- **`@ViewBuilder` + `if` para condicionais**: nunca `AnyView(EmptyView())` — prejudica diff tree do SwiftUI
- **git query para branch**: usar `Process` em `Task.detached` ou `Thread` (nao em metodo de ator diretamente);
  resultado seta o campo via metodo do ator na borda

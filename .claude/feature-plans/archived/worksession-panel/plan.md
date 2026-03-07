# Plan: worksession-panel

## Problema

O dashboard atual tem 3 pollers independentes e nenhuma entidade unificada de "work session" — o dev
precisa correlacionar manualmente dados de `SessionStore`, `GitStateService` e Kanban em views
diferentes. O objetivo é um overview panel que agrega `AgentSession + WorktreeInfo + KanbanFeature`
por projeto numa entidade runtime `WorkSession`, ordenada por urgência (`HITL_PENDING > ERROR > RUNNING > DONE > IDLE`),
com aprovação de HITL inline nas rows.

## Assunções

<!-- status: [assumed] = não verificada | [verified] = confirmada | [invalidated] = refutada -->
<!-- risco:   [blocking] = falsa bloqueia a implementação | [background] = emerge naturalmente -->

- [assumed][blocking] As 3 worktrees conflitantes (`session-cards-hitl-ui`, `docs-lifecycle`, `session-restore-install`) terão suas branches mergeadas no main **antes** de criar a worktree de `worksession-panel`
- [verified][blocking] O usuário confirma onde `WorkSessionPanelView` deve aparecer no UI → opção D (tab dentro do projeto)
- [verified][background] `WorkSession` é runtime-only — não `@Model` SwiftData; identidade via `worktree.path` (string estável)
- [verified][background] `WorkSessionService` usa poll timer (2s) para git + kanban; lê `SessionStore.sessions` via snapshot no mesmo tick (sem `withObservationTracking` — issue Swift #83359)
- [assumed][background] O floating HITL panel continua existindo; inline HITL é complementar — `approveHITL`/`rejectHITL` são idempotentes
- [assumed][background] `KanbanReader.load(projectPath:)` é síncrono e rápido o suficiente para chamar no tick do poll

## Questões abertas

**Resolver antes de começar (human gate now):**

- As branches `session-cards-hitl-ui`, `docs-lifecycle` e `session-restore-install` estão mergeadas no main? Criar worktree antes garante conflitos em hot files compartilhados
- Onde `WorkSessionPanelView` deve aparecer? Opções:
  - (a) Nova entrada na sidebar principal (requer mudança em `NavigationSplitView` raiz)
  - (b) Toolbar button que abre como sheet sobre a janela principal
  - (c) Janela separada via `openWindow(id:value:)` (mais isolado, menos integrado)
  - (d) Nova tab dentro de um projeto selecionado (localizada ao contexto de projeto)

**A implementação vai responder (monitorar):**

- O join via `hasPrefix` entre `session.cwd` e `worktree.path` é suficiente para todos os layouts reais de worktree do usuário
- Performance do `recomputeWorkSessions()` no @MainActor com N worktrees ativas (expectativa: ≤ 8, aceitável sincronamente)

**Explicitamente fora do escopo:**

- Substituir ou remover pollers existentes nas views atuais (`WorktreesView`, `AgentCardView`)
- Persistência de `WorkSession` em SwiftData — entidade runtime
- Criação ou deleção de worktrees pelo panel
- Configuração de polling interval pelo usuário

## Deliverables

### Deliverable 1 — Walking Skeleton

**O que faz:** `WorkSession` model + `WorkSessionService` com join `worktree↔session↔kanban` + `WorkSessionPanelView`
básica mostrando a lista sorted por urgência (sem HITL inline ainda).

**Critério de done:** Rodar o app, abrir o panel, ver as worktrees ativas listadas em ordem de urgência
(`HITL_PENDING` primeiro, `IDLE` por último). Sem worktrees, lista vazia. Sem crash.

**Valida:** join via `hasPrefix`, identidade estável com `id = worktree.path`, `didSet` observers para
recompute, `WorkSessionService` como `@MainActor @Observable` singleton, poll sem bloquear UI.

**Resolve:** "o agregador funciona e os dados chegam corretamente na view"

**Deixa aberto:** botões HITL inline, supressão do floating panel, localização final no UI

**⚠️ Execute `/checkpoint` antes de continuar para o Deliverable 2.**

### Deliverable 2 — Inline HITL + Integração

**O que faz:** `WorkSessionRowView` com botões Approve/Reject inline (`.buttonStyle(.plain)`),
wire para `SessionManager.approveHITL`/`rejectHITL`, supressão do floating HITL panel quando
inline HITL está disponível, `AppDelegate` inicia `WorkSessionService`.

**Critério de done:** Com sessão em estado `awaitingInput`, o panel mostra botões Approve/Reject
na row correta. Clicar Approve: botões somem, floating panel não aparece concorrentemente.
`AppDelegate` inicia o serviço sem crash no launch.

**Valida:** HITL double-fire mitigation via `approveHITL` idempotente, supressão de `HITLFloatingPanelController`
quando inline HITL ativo, padrão `@Observable HITLPanelState` sem `rootView =`.

**Resolve:** "aprovação inline funciona sem racing com o floating panel"

## Arquivos a modificar

Criados do zero (sem conflito):

- `ClaudeTerminal/Models/WorkSession.swift` — struct runtime com `id`, `urgency`, `worktreeInfo`, `session?`, `kanbanFeature?`
- `ClaudeTerminal/Services/WorkSessionService.swift` — `@MainActor @Observable` singleton; `didSet` observers; `recomputeWorkSessions()`; urgency sort; poll timer 2s
- `ClaudeTerminal/Features/WorkSession/WorkSessionPanelView.swift` — `List` observando `WorkSessionService.shared.workSessions`
- `ClaudeTerminal/Features/WorkSession/WorkSessionRowView.swift` — row com status badge, feature title, inline HITL buttons com `.buttonStyle(.plain)`

Modificados (aguardam merge das branches conflitantes):

- `ClaudeTerminal/App/AppDelegate.swift` — adicionar `WorkSessionService.shared.start()` em `applicationDidFinishLaunching` [⚠️ aguardar merge de `session-cards-hitl-ui`]
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — suprimir floating panel quando `WorkSessionService` tem HITL inline ativo [⚠️ aguardar merge de `docs-lifecycle`]
- Entry point do UI (a definir) — adicionar `WorkSessionPanelView`

## Passos de execução

1. Confirmar que branches conflitantes mergearam; confirmar localização do UI — **human gate** [pré-condição]
2. `git fetch origin && git rebase origin/main` no repo principal [pré-condição]
3. Ler hot files: `SessionStore.swift`, `SessionManager.swift` (métodos `approveHITL`/`rejectHITL`), `GitStateService.swift` (`worktrees()`), `WorktreesView.swift` (padrão `hasSession()`), `HITLFloatingPanelController.swift` (padrão `HITLPanelState`), `BacklogKanbanModels.swift` (`KanbanReader`) [Deliverable 1]
4. Criar `ClaudeTerminal/Models/WorkSession.swift` — struct + `UrgencyTier` enum + `urgency` computed var [Deliverable 1]
5. Criar `ClaudeTerminal/Services/WorkSessionService.swift` — singleton, `gitWorktrees`/`sessions`/`kanbanFeatures` com `didSet`, `recomputeWorkSessions()`, poll timer 2s, urgency sort, `start()` [Deliverable 1]
6. Criar `ClaudeTerminal/Features/WorkSession/WorkSessionPanelView.swift` — `List` com `ForEach` em `workSessions`, row básica com nome e urgency badge [Deliverable 1]
7. Adicionar entry point temporário no UI para abrir `WorkSessionPanelView` (toolbar button ou menu item) [Deliverable 1]
8. Build: `swift build` — deve compilar sem erros [Deliverable 1]
9. ⚠️ Execute `/checkpoint` — Deliverable 1 concluído
10. Criar `ClaudeTerminal/Features/WorkSession/WorkSessionRowView.swift` — row completa com inline HITL buttons, `.buttonStyle(.plain)`, wire para `SessionManager` [Deliverable 2]
11. Substituir placeholder em `WorkSessionPanelView` pelo `WorkSessionRowView` completo [Deliverable 2]
12. Modificar `HITLFloatingPanelController.swift` — suprimir floating panel quando WorkSession tem HITL inline disponível [Deliverable 2]
13. Modificar `AppDelegate.swift` — `WorkSessionService.shared.start()` em `applicationDidFinishLaunching` [Deliverable 2]
14. Build: `swift build` — deve compilar sem erros [Deliverable 2]

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda (AppDelegate apenas — não afeta entitlements nem Package.swift)
- [ ] Novas dependências: não (reusa `GitStateService`, `KanbanReader`, `SessionStore`, `SessionManager`)

## Rollback

```bash
# Arquivos novos — deletar
rm -f ClaudeTerminal/Models/WorkSession.swift
rm -f ClaudeTerminal/Services/WorkSessionService.swift
rm -rf ClaudeTerminal/Features/WorkSession/

# Arquivos modificados — reverter
git checkout -- ClaudeTerminal/App/AppDelegate.swift
git checkout -- ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift
# Entry point do UI: reverter conforme o arquivo escolhido
```

## Learnings aplicados

- `didSet` em vez de `withObservationTracking` para join multi-source (Swift issue #83359 perde updates concorrentes)
- `id = worktree.path` para identidade estável — sem isso rows flickam a cada poll cycle
- `.buttonStyle(.plain)` obrigatório em botões dentro de `List` rows no macOS (bug FB12285575)
- `@Observable HITLPanelState` compartilhado — nunca `hosting.rootView =` (EXC_BREAKPOINT no macOS 26)
- `Task { @MainActor in SessionStore.shared.update() }` como padrão de bridge actor → @Observable
- `@ViewBuilder` + `if` para views condicionais — sem `AnyView`
- `TimelineView(.periodic(from: .now, by: 1.0))` para elapsed time live em rows
- Não incluir `lastUpdate: Date` na equalidade de `WorkSession` — dispara animation em todo poll cycle

# Changelog

---

## [feat] hitl-rich-context-card — contexto rico no card de aprovação HITL — 2026-03-07

**Tipo:** feat
**Tags:** hitl, ui, ux, hook-handler
**PR:** [#68](https://github.com/rmolines/claude-terminal/pull/68) · **Complexidade:** simples

### O que mudou

O card de aprovação HITL agora mostra o contexto real da operação: para ferramentas de arquivo
(Write, Edit, Read, Glob, Grep) aparece o file path; para Bash aparece o comando exato. O nome
da tool virou um badge colorido com ícone SF Symbol por categoria, facilitando triagem visual.

### Detalhes técnicos

- `HookHandler.swift`: chain `command` → `file_path` → `path` → `pattern` → `description` → `toolName` para permissionRequest; prefix 80→120 chars
- `ApprovalCardView.swift`: `ToolBadge` struct com SF Symbol + capsule colorida (Bash=red, Write/Edit=blue, Read/Glob/Grep=secondary, WebFetch=teal); 3 novos `#Preview` blocks

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminalHelper/HookHandler.swift` — extração de detail expandida
- `ClaudeTerminal/Features/SessionCards/ApprovalCardView.swift` — ToolBadge view

---

## [feat] agent-message-input — TextField inline para enviar mensagens ao agente — 2026-03-07

**Tipo:** feat
**Tags:** ui, pty, sessions, message-input
**PR:** [#67](https://github.com/rmolines/claude-terminal/pull/67) · **Complexidade:** simples

### O que mudou

Cada row de sessão ativa no Sessions tab agora tem um TextField "Message agent…".
Digitar e pressionar Enter injeta o texto diretamente no PTY do agente — permite
responder mid-run questions sem abrir um terminal separado.

### Detalhes técnicos

- `WorkSessionRowView`: novo `messageInputRow` com `TextField` + botão ↑
- `sendMessage`: `Array(text.utf8) + [0x0d]` via `TerminalRegistry.shared.sendInput(forCwd:)`
- Botão desabilitado/cinza quando `messageText.isEmpty`; accent quando há texto
- Campo visível apenas quando `workSession.session != nil`
- Suite `.claude/commands/test/` com 5 skills de teste determinísticos (hitl-bash, hitl-write,
  question, long-run, stop)

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Features/WorkSession/WorkSessionRowView.swift` — messageInputRow + sendMessage
- `.claude/commands/test/` — test skills

---

## [feat] worksession-panel — Sessions tab com inline HITL e urgency sort — 2026-03-06

**Tipo:** feat
**Tags:** ui, hitl, worktrees, sessions
**PR:** [#66](https://github.com/rmolines/claude-terminal/pull/66) · **Complexidade:** média

### O que mudou

Nova aba **Sessions** dentro de cada projeto mostra todas as worktrees ativas ordenadas por urgência — HITL pendente primeiro, idle por último.
Sessions com aprovação pendente exibem botões Approve/Reject inline, sem abrir o floating panel.

### Detalhes técnicos

- `WorkSession` struct runtime com `UrgencyTier` (hitlPending > error > running > done > idle)
- `WorkSessionService` singleton `@MainActor @Observable`: poll 2s, join `worktree↔AgentSession↔KanbanFeature`, urgency sort
- `WorkSessionPanelView` + `WorkSessionRowView`: List com inline HITL buttons (`.buttonStyle(.plain)`)
- `HITLFloatingPanelController`: suprime floating panel quando inline HITL disponível na aba Sessions
- `AppDelegate`: `WorkSessionService.shared.start()` no launch

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Models/WorkSession.swift` — struct + UrgencyTier
- `ClaudeTerminal/Services/WorkSessionService.swift` — singleton, poll, join
- `ClaudeTerminal/Features/WorkSession/WorkSessionPanelView.swift` — List view
- `ClaudeTerminal/Features/WorkSession/WorkSessionRowView.swift` — row com inline HITL
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — +tab Sessions

---

## [feat] Polish sprint registry — chores[] + --close + compass — 2026-03-06

**Tipo:** feat
**Tags:** skills, workflow, backlog, polish
**PR:** [#65](https://github.com/rmolines/claude-terminal/pull/65) · **Complexidade:** simples

### O que mudou

`/polish` agora registra cada sessao em `backlog.json` (array `chores[]`) apos abrir o PR,
e suporta `/polish --close` para marcar o registro como `"merged"` e limpar a branch.
`/project-compass` exibe uma tabela "Chores recentes" quando `chores[]` nao esta vazio.

### Detalhes tecnicos

- `backlog.json`: novo array top-level `"chores": []`
- `polish.md`: flag `--close` (guard + jq status update + delete branch); Passo 5 com `swift test`
  - RenderPreview para UI; Passo 6b com jq write em `chores[]`
- `project-compass.md`: Phase 1c extrai `chores[]`; Phase 3 tabela "Chores recentes" (omitida se vazia)

### Impacto

- **Breaking:** Nao

### Arquivos-chave

- `.claude/backlog.json` — array `chores[]` adicionado
- `.claude/commands/polish.md` — flag `--close` + Passo 6b
- `.claude/commands/project-compass.md` — Phase 1c + Phase 3

---

## [feat] Session dashboard + HITL approval queue — 2026-03-06

**Tipo:** feat
**Tags:** ui, hitl, supervision, session-management
**PR:** [#64](https://github.com/rmolines/claude-terminal/pull/64) · **Complexidade:** alta

### O que mudou

O app agora tem um dashboard "All Sessions" no sidebar que mostra todos os terminais abertos em tempo real
com identidade (projeto, branch, fase, status, elapsed time). O painel de aprovação HITL foi substituído
por uma fila que exibe todos os agentes pendentes simultaneamente — cada um com approve/reject independente
e badge de risco.

### Detalhes técnicos

- `SessionCardsContainerView`: grid por projeto com TimelineView pai (elapsed time a cada segundo), filtrado para projetos com terminal aberto no app
- `SessionCardView/Header`: status badge colorido, branch (git query async via Thread), fase WorkflowPhase, currentActivity, última notificação do Claude, token badge
- `RiskSurfaceComputer`: pattern matching isolado para critical (rm -rf, push --force) / elevated / normal
- `HITLQueueView + ApprovalCardView`: substitui single-modal por fila scrollável — todos os HITLs pendentes visíveis ao mesmo tempo
- `SessionManager`: adiciona `branch` e `pendingToolName` ao `AgentSession`; toolName forwarded por toda a pipeline de hooks
- `SessionStore`: evicção de synthetic sessions escopada por cwd (bug: era global)
- `MainView`: ZStack externo mantém PTYs vivos quando o dashboard está visível
- `AppDelegate`: fecha janelas extras de macOS state restoration no launch

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Features/SessionCards/` — 5 novos arquivos (container, card, header, approval, risk)
- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — HITLQueueView + HITLPanelState com lista
- `ClaudeTerminal/Features/Terminal/MainView.swift` — "All Sessions" + ZStack preservado

---

## [improvement] mcp-session-preflight: preflight probes + session-type annotation — 2026-03-06

**Tipo:** improvement
**Tags:** skills, developer-experience, mcp, workflow
**PR:** [#63](https://github.com/rmolines/claude-terminal/pull/63) · **Complexidade:** simples

### O que mudou

Skills MCP-dependentes agora detectam ativamente quando o Xcode MCP está desconectado e
exibem uma mensagem de remediação clara em vez de falhar silenciosamente mid-session.

### Detalhes técnicos

- `design-review.md`: `RenderPreview` virou hard gate — obrigatório quando `#Preview` existe.
  Se a chamada falhar (MCP desconectado), exibe `[SEM MCP]` com instrução: feche a sessão,
  abra `Package.swift` no Xcode e inicie nova sessão do Claude Code
- `ship-feature.md` passo 0.5: tenta `BuildProject` (MCP) primeiro para erros estruturados;
  se falhar, emite aviso e usa `swift build` como fallback transparente
- `start-feature.md`: handoff blocks de Fase 0 e A anotados como `Tipo de sessão: A`;
  Fase B determina tipo A/B por presença de `*View.swift` no plan.md; Fase C.1 exibe
  `[PREREQUISITO UI]` quando plan.md lista views SwiftUI

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/commands/design-review.md` — RenderPreview hard gate + [SEM MCP] message
- `.claude/commands/ship-feature.md` — BuildProject probe + swift build fallback
- `.claude/commands/start-feature.md` — session-type annotation + UI prerequisite warning

---

## [improvement] Delivery summary no /close-feature — 2026-03-06

**Tipo:** improvement
**Tags:** skills, workflow, developer-experience
**PR:** [#61](https://github.com/rmolines/claude-terminal/pull/61) [#62](https://github.com/rmolines/claude-terminal/pull/62) · **Complexidade:** simples

### O que mudou

`/close-feature` Step 4 agora exibe um bloco "O que foi entregue" antes do checklist de
documentação: resumo da feature, o que mudou e arquivos principais — extraídos do `plan.md`
ou do título do PR. Também sincroniza `checkpoint.md` do upstream kickstart.

### Detalhes técnicos

- `.claude/commands/close-feature.md`: Step 4 reescrito com template de delivery summary
- `.claude/commands/checkpoint.md`: sincronizado do kickstart (c511012)
- Propagado para `rmolines/claude-kickstart` PR #26

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/commands/close-feature.md` — Step 4 com delivery summary block

---

## [feat] Kanban tab — visão kanban read-only do backlog.json — 2026-03-06

**Tipo:** feat
**Tags:** ui, kanban, backlog, workflow, swiftui
**PR:** [#60](https://github.com/rmolines/claude-terminal/pull/60) · **Complexidade:** média

### O que mudou

Nova aba "Kanban" no `ProjectDetailView`: exibe features do `backlog.json` em 3 colunas
(Todo / Doing / Done) agrupadas por milestone, com auto-refresh a cada 30s. O app é
somente leitura — skills continuam sendo o editor canônico do JSON.

### Detalhes técnicos

- `BacklogKanbanModels.swift`: structs Decodable independentes (`KanbanMilestone`,
  `KanbanFeature`, `KanbanBacklogFile`, `KanbanReader`) — não toca `WorkflowStateReader`
- Novos campos opcionais (`labels`, `sortOrder`, `updatedAt`) — backward-compatible
- `FlowLayout` custom (SwiftUI Layout protocol) para wrapping de chips de labels
- Poll 30s via `.task { while !Task.isCancelled { ... } }` — padrão do WorkflowGraphView

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Features/Kanban/BacklogKanbanModels.swift` — data layer
- `ClaudeTerminal/Features/Kanban/KanbanView.swift` — UI (colunas, cards, FlowLayout)
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — enum case + tab item

---

## [fix] kickstart-dirty-guard — pre-flight check antes de sync/propagação — 2026-03-06

**Tipo:** fix
**Tags:** skills, developer-experience, sync-skills, close-feature
**PR:** [#58](https://github.com/rmolines/claude-terminal/pull/58) · **Complexidade:** simples

### Problema

`close-feature` e `sync-skills` falhavam com "Your local changes would be overwritten" quando o kickstart
ou `.claude/commands/` tinham mudanças locais não-commitadas. Nenhuma skill verificava o estado antes de iniciar o fluxo.

### Fix aplicado

Adicionado `git status --porcelain` como pre-flight em ambas as skills. Se sujo: exibe os arquivos
afetados + opções (stash/commit/abort) e sai com erro antes de qualquer operação destrutiva.

### Arquivos-chave

- `.claude/commands/close-feature.md` — guard no início do passo 1g
- `.claude/commands/sync-skills.md` — guard antes do `git checkout upstream/main`

---

## [fix] HITL panel crash — @Observable state elimina rootView= no macOS 26 — 2026-03-06

**Tipo:** fix
**Tags:** hitl, appkit, crash, swiftui
**PR:** [#57](https://github.com/rmolines/claude-terminal/pull/57) · **Complexidade:** simples

### Problema

Crash `EXC_BREAKPOINT (SIGTRAP)` em `_postWindowNeedsUpdateConstraints` após horas de uso.
O guard de cache (sessionID + description) evitava atualizações redundantes mas não protegia
o caso de um segundo request HITL com conteúdo diferente — que ainda chamava `hosting.rootView = view`
durante um layout cycle ativo do AppKit.

### Fix aplicado

Introduzida `HITLPanelState` (`@Observable`) como estado compartilhado. `NSHostingView` é criado
uma vez com `HITLPanelView(state:)` e nunca tem `rootView =` chamado novamente. Mutações de estado
são diffadas internamente pelo SwiftUI sem invalidar constraints.

### Arquivos-chave

- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — `HITLPanelState` + view refatorada
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — remove `rootView =`, usa `panelState`

---

## [fix] skill-drift-notification — remover pop-up macOS do hook de startup — 2026-03-06

**Tipo:** fix
**Tags:** hooks, developer-experience, skills
**PR:** N/A (arquivo global `~/.claude/hooks/`) · **Complexidade:** simples

### Problema

Hook `session-start-freshness.sh` disparava notificação macOS via `osascript` ao detectar drift de skills — pop-up desnecessário pois o aviso já aparecia como `system-reminder` direto na sessão.

### Fix aplicado

Removida a linha `osascript` (linha 88). Aviso de drift agora é apenas via stdout → contexto da sessão.

### Arquivos-chave

- `~/.claude/hooks/session-start-freshness.sh` — linha 88 removida

---

## [feat] skill-freshness-check — hook de detecção de drift de skills — 2026-03-06

**Tipo:** feat
**Tags:** skills, hooks, developer-experience
**PR:** N/A (feature global, fora do repo) · **Complexidade:** média

### O que mudou

Hook de SessionStart que compara `~/.claude/commands/` com o `rmolines/claude-kickstart` remoto
a cada sessão startup. Detecta arquivos modificados, faltando localmente ou deletados no upstream.
Notifica via macOS notification e injeta contexto plain text para o Claude.

### Detalhes técnicos

- `~/.claude/hooks/session-start-freshness.sh` — git fetch + hash comparison (shasum -a 256) por arquivo
- `~/.claude/settings.json` — entrada `SessionStart` com `matcher: "startup"` (escrita atômica via mktemp + os.replace)
- Timeout de 3s no fetch via subshell + kill (sem `timeout` command no macOS)
- Saída plain text stdout (hookSpecificOutput JSON não é suportado em SessionStart)
- osascript notification para visibilidade garantida (stderr de hooks não aparece no terminal)

### Impacto

- **Breaking:** Não
- Notificação macOS ao iniciar sessão quando há drift
- Claude vê o drift no contexto e menciona proativamente

### Arquivos-chave

- `~/.claude/hooks/session-start-freshness.sh` — script principal
- `~/.claude/settings.json` — hook registrado em `hooks.SessionStart`

---

## [feat] New Worktree sheet — criar worktrees diretamente pelo app — 2026-03-06

**Tipo:** feat
**Tags:** worktrees, terminal, ux
**PR:** [#55](https://github.com/rmolines/claude-terminal/pull/55) · **Complexidade:** média

### O que mudou

Dev pode criar um novo worktree git e abrir o terminal nele sem sair do app.
Botão "+" na aba Worktrees abre uma sheet com validação, preview do branch e opção de injetar `/start-feature` automaticamente.

### Detalhes técnicos

- `NewWorktreeSheet.swift`: validação kebab-case em tempo real, coerce automático, toggle de injeção
- `GitStateService.addWorktree(name:in:)`: `git worktree add` com fallback `main` → `master`
- `WorktreesView`: callback `onSelect(path, initialInput?)` — agora passa input opcional
- `ProjectDetailView`: `pendingInitialInput` por path, limpo no Restart

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Features/Worktrees/NewWorktreeSheet.swift` — novo
- `ClaudeTerminal/Features/Worktrees/WorktreesView.swift`
- `ClaudeTerminal/Services/GitStateService.swift`
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift`

---

## [fix] Skill flow robustness: CI gate + sync-skills rebase + rule accuracy — 2026-03-06

**Tipo:** fix
**Tags:** skills, ci, workflow, ship-feature, close-feature
**PR:** [#56](https://github.com/rmolines/claude-terminal/pull/56) · **Complexidade:** simples

### Problema

3 pontos de fricção residual no fluxo ship→close causavam comportamento inesperado em sessões
reais: CI gate lia run antigo após re-push de fix (risco de merge com CI vermelho); sync-skills
conflitava com origin/main quando a feature tocou skills; regra "Nunca fazer commit" no
close-feature estava incorreta e causava confusão.

### Fix aplicado

- `ship-feature` passo 6: documentado padrão `gh run list → gh run watch <id>` para uso após
  re-push de fix (evita leitura de run antigo)
- `ship-feature` passo 1: instrução explícita de usar `commit-commands:commit` sub-skill
- `close-feature` passo 1g: `git pull --rebase origin main` adicionado antes de `make sync-skills`
- `close-feature` Regras: redação correta — commits de docs e sync em main são permitidos

### Arquivos-chave

- `.claude/commands/ship-feature.md` — passo 1 e passo 6
- `.claude/commands/close-feature.md` — passo 1g e seção Regras

---

## [fix] HITL buttons now dismiss terminal TUI dialog — 2026-03-05

**Tipo:** fix
**Tags:** hitl, pty, terminal, ux
**PR:** [#54](https://github.com/rmolines/claude-terminal/pull/54) · **Complexidade:** simples

### Problema

Clicar Approve/Reject no painel HITL flutuante não tinha efeito visível no terminal.
Claude Code usa dois mecanismos simultâneos: hook `PermissionRequest` (socket, já funcionava)
e um TUI dialog interativo no PTY (raw mode, exigia input de teclado). O TUI ficava travado.

### Fix aplicado

Após responder ao socket, `approveHITL` envia `[0x31]` ("1") e `rejectHITL` envia `[0x1b]`
(Escape) diretamente ao PTY via `TerminalRegistry.sendInput(_:forCwd:)`, descartando o TUI dialog.

### Arquivos-chave

- `ClaudeTerminal/Services/SessionManager.swift` — `approveHITL` + `rejectHITL`
- `ClaudeTerminal/Services/TerminalRegistry.swift` — novo método `sendInput(_:forCwd:)`

---

## [fix] ASSERT guards nas skills ship/close/start-feature — 2026-03-06

**Tipo:** fix
**Tags:** skills, workflow, ci-gate, worktrees
**PR:** [#53](https://github.com/rmolines/claude-terminal/pull/53) · **Complexidade:** simples

### Problema

Dois bugs estruturais de ordering causavam retrabalho sistemático:

1. `close-feature` usava paths relativos sem assertar CWD == REPO_ROOT — docs iam para worktree
   morta e precisavam ser reescritos em main
2. `ship-feature` chamava `merge_pull_request` antes de verificar CI — merges com CI vermelho
   geravam branch de emergência + novo PR + nova espera

### Fix aplicado

- `close-feature`: ASSERT REPO_ROOT no início do passo 1 + absolute paths em todos os writes
  (HANDOVER.md, CHANGELOG.md, LEARNINGS.md, CLAUDE.md, backlog.json); ASSERT CWD ≠ worktree antes
  do `worktree remove`
- `ship-feature`: `gh pr checks --watch` antes de `merge_pull_request` — CI vermelho bloqueia merge
- `start-feature`: `git ls-remote --heads origin` antes de `EnterWorktree` — evita colisão com
  branch de sessão anterior

### Arquivos-chave

- `.claude/commands/close-feature.md` — REPO_ROOT assert + absolute paths
- `.claude/commands/ship-feature.md` — CI gate antes do merge
- `.claude/commands/start-feature.md` — ASSERT branch remota antes de criar worktree

---

## [fix] Sparkle updater não iniciava — chave EdDSA ausente — 2026-03-06

**Tipo:** fix
**Tags:** updater, sparkle, infoplist
**PR:** [#52](https://github.com/rmolines/claude-terminal/pull/52) · **Complexidade:** simples

### Problema

Ao clicar "Check for Updates…", o app exibia "The updater failed to start".
`SUPublicEDKey` em `Info.plist` tinha o placeholder `REPLACE_WITH_PUBLIC_KEY_FROM_generate_keys`
desde o bootstrap — o Sparkle recusa iniciar sem uma chave EdDSA válida.

### Fix aplicado

Rodado `.build/artifacts/sparkle/Sparkle/bin/generate_keys` — retornou a chave pré-existente
no Keychain e inserida em `Info.plist`.

### Arquivos-chave

- `ClaudeTerminal/App/Info.plist` — `SUPublicEDKey` com valor real

---

## [feat] Nova skill /polish para sessões de batch cleanup — 2026-03-06

**Tipo:** feat
**Tags:** skills, workflow
**PR:** [#50](https://github.com/rmolines/claude-terminal/pull/50) · **Complexidade:** simples

### O que mudou

Nova skill `/polish` disponível. Use quando tem N melhorias pequenas e conhecidas para
executar: uma branch, micro-commit por item, um PR com todos os commits preservados.

### Detalhes técnicos

- `/polish` — coleta lista de tarefas upfront, loop autônomo com micro-commit por item, PR único no final
- PR usa `mergeMethod: "merge"` (não squash) para preservar rastreabilidade por item
- Skill propagada para `rmolines/claude-kickstart` (PR #20) como template genérico

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/commands/polish.md` — skill criada
- `.claude/rules/workflow.md` — /polish adicionado ao fluxo visual e tabela de skills

---

## [fix] Terminal mostra overlay "Session ended" ao sair do Claude — 2026-03-06

**Tipo:** fix
**Tags:** terminal, pty, swifttterm, ux
**PR:** [#49](https://github.com/rmolines/claude-terminal/pull/49) · **Complexidade:** simples

### Problema

Ao digitar `exit` (ou Ctrl+D) no terminal do app, a sessão Claude encerrava mas a view ficava
congelada — sem feedback visual e sem forma de iniciar uma nova sessão exceto clicando no botão
`↺` do header (que muitos usuários não descobriam).

### Fix aplicado

`processTerminated` no `Coordinator` era um no-op. Agora dispara `onProcessTerminated` callback
no `@MainActor`. `ProjectDetailView` rastreia `deadPaths: Set<String>` e exibe overlay
"Session ended" com botão **Restart** sobre o terminal morto.

### Arquivos-chave

- `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift` — `onProcessTerminated` callback + `processTerminated` implementado
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — `deadPaths` state + overlay

---

## [chore] Sync skills from upstream + docs update — 2026-03-05

**Tipo:** chore
**Tags:** skills, workflow, docs
**PR:** [#46](https://github.com/rmolines/claude-terminal/pull/46) · **Complexidade:** simples

### O que mudou

Skills de workflow sincronizadas com o upstream `claude-kickstart` (db742b0) e documentação
dos fixes de HITL atualizada em CHANGELOG, HANDOVER, LEARNINGS e CLAUDE.md.

### Detalhes técnicos

- `propagate-skills.md` — nova skill para sincronizar skills entre camadas projeto e global
- `close-feature.md` — removidos passos redundantes (0.6/0.7, 1f, 2.5)
- `ship-feature.md` — gate `/validate` antes do PR + merge step simplificado
- `start-feature.md` — seção "sem roadmap" + tabela de flags atualizada + conflitos resolvidos
- `start-milestone.md` + `validate.md` + `fix.md` + `checkpoint.md` — melhorias pontuais
- CLAUDE.md: nova armadilha `toolInput["command"]` vs `["description"]`

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/commands/` — 8 skills atualizadas + 1 nova
- `CLAUDE.md`, `CHANGELOG.md`, `HANDOVER.md`, `LEARNINGS.md` — docs

---

## [fix] HITL panel nunca fechava + descrição sempre genérica — 2026-03-05

**Tipo:** fix
**Tags:** hitl, session-manager, hook-handler
**PR:** [#45](https://github.com/rmolines/claude-terminal/pull/45) · **Complexidade:** simples

### Problema

O painel HITL aparecia mas os botões Approve/Reject não faziam nada visualmente (o painel
ficava aberto). Além disso, o painel sempre mostrava "Awaiting approval" em vez do comando
real que o agente queria executar.

### Fix aplicado

- `approveHITL`/`rejectHITL` agora propagam o status atualizado ao `SessionStore`, permitindo que o painel feche imediatamente
- `HookHandler` agora extrai o comando de `toolInput["command"]` (Bash) em vez de `toolInput["description"]` (que era sempre `nil`)

### Arquivos-chave

- `ClaudeTerminal/Services/SessionManager.swift` — SessionStore.update() adicionado em approve/reject
- `ClaudeTerminalHelper/HookHandler.swift` — extração de detail corrigida

---

## [fix] HITL panel crash em postWindowNeedsUpdateConstraints — 2026-03-05

**Tipo:** fix
**Tags:** hitl, appkit, crash
**PR:** [#44](https://github.com/rmolines/claude-terminal/pull/44) · **Complexidade:** simples

### Problema

App crashava com `EXC_BREAKPOINT (SIGTRAP)` após ~1h de uso quando um agente entrava em
modo de aprovação HITL. O painel flutuante era atualizado em cada hook event (heartbeats,
bash commands, etc.), causando invalidação de constraints do `NSHostingView` durante um
layout cycle do AppKit — que lança `NSException` em `postWindowNeedsUpdateConstraints`
no macOS 26 (mais estrito que versões anteriores).

### Fix aplicado

`HITLFloatingPanelController.show()` agora guarda `currentSessionID` + `currentDescription`
e pula `hosting.rootView = view` quando o painel já está visível com o mesmo conteúdo.
O cache é limpo quando o painel é dispensado.

### Arquivos-chave

- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — guard em `show()`, cache limpo no dismiss

---

## [improvement] Skill flow improvements — architecture design + quality review — 2026-03-05

**Tipo:** improvement
**Tags:** skills, workflow, architecture, quality
**PR:** [#38](https://github.com/rmolines/claude-terminal/pull/38) · **Complexidade:** simples

### O que mudou

`/start-feature` ganha duas novas etapas: arquitetos paralelos propõem abordagens de implementação
antes do plano (B.2), e revisores paralelos auditam qualidade após o build (C.6.5).
`workflow.md` corrige o fluxo PITCH e adiciona `/design-review` como gate obrigatório para features com UI.

### Detalhes técnicos

- `start-feature.md` B.2: 3 arquitetos (Minimal/Clean/Pragmatic) em paralelo; síntese comparativa + escolha do usuário
- `start-feature.md` C.6.5: 3 revisores (Simplicity/Bugs/Conventions) em paralelo após build verde
- `workflow.md`: PITCH flow corrigido; `/design-review` no TÁTICO e AD-HOC; tabela `--discover` corrigida
- Lint: 36 erros → 0 em CHANGELOG.md, HANDOVER.md, checkpoint.md

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/rules/workflow.md` — fluxos e tabela de skills
- `.claude/commands/start-feature.md` — Fase B (B.2) e Fase C (C.6.5)

---

## [feat] Multi-project workspace — sidebar + PTYs persistentes — 2026-03-05

**Tipo:** feat
**Tags:** swiftdata, multi-terminal, navigation, pty
**PR:** [#37](https://github.com/rmolines/claude-terminal/pull/37) · **Complexidade:** alta

### O que mudou

O app agora gerencia múltiplos projetos simultaneamente. Uma sidebar lista repositórios git;
trocar de projeto preserva a sessão Claude ativa (PTY continua rodando em segundo plano via ZStack).

### Detalhes técnicos

- `ClaudeProject` @Model (SwiftData) com git root como chave canônica — worktrees do mesmo repo
  aparecem sob um único projeto via `git rev-parse --git-common-dir`
- `MainView` reescrito: `NavigationSplitView` + `ZStack` com `opacity(0/1)` em vez de `TabView`
- `migrateIfNeeded()` converte `@AppStorage("workingDirectory")` + `recentDirectoriesData` → entities
- `cleanupAndDeduplicateProjects()` mescla duplicatas, remove orphans e corrige displayPaths stale
- `ProjectDetailView` com header de path + branch menu + tabs (Terminal/Skills/Worktrees)

### Impacto

- **Breaking:** Não — store distinto (`ClaudeTerminalProjectsV1.store`); dados antigos migrados

### Arquivos-chave

- `ClaudeTerminal/Models/ClaudeProject.swift` — novo @Model
- `ClaudeTerminal/Models/AppMigrationPlan.swift` — novo ModelContainer factory
- `ClaudeTerminal/Features/Terminal/MainView.swift` — reescrito
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — novo
- `ClaudeTerminal/Services/GitStateService.swift` — adicionado `gitRootPath(for:)`

---

## [improvement] Absorver ideias do Superpowers — intake + verification + TDD — 2026-03-05

**Tipo:** improvement
**Tags:** skills, tdd, intake, verification
**PR:** [#36](https://github.com/rmolines/claude-terminal/pull/36) · **Complexidade:** simples

### O que mudou

Skills de desenvolvimento ganham três novos guardrails: intake mais focado (uma pergunta por vez),
gate obrigatório de build+test antes de qualquer PR, e regra de TDD sempre em contexto.

### Detalhes técnicos

- `start-feature.md` Fase 0: regra "uma pergunta por vez, prefira múltipla escolha" nas rodadas de intake
- `ship-feature.md`: Passo 0.5 (HARD GATE) roda `{{BUILD_CMD}}` + `{{TEST_CMD}}` antes de qualquer commit
- `.claude/rules/tdd.md`: novo rule file com ciclo RED/GREEN/REFACTOR e escopo no projeto

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/commands/start-feature.md` — regra de intake Fase 0
- `.claude/commands/ship-feature.md` — Passo 0.5 + Regras
- `.claude/rules/tdd.md` — novo

---

## [fix] Sinalizar saltos invisíveis em plan-roadmap e ship-feature (Lei 3/4) — 2026-03-04

**Tipo:** fix
**Tags:** skills, audit, lei-4, kickstart
**PR:** [#14](https://github.com/rmolines/claude-kickstart/pull/14) (kickstart) · **Complexidade:** simples

### Problema

`/plan-roadmap` lia artefatos de `/start-project` silenciosamente sem avisar o dev quais foram encontrados.
`/ship-feature` pulava o checklist de infra sem nenhum sinal quando `plan.md` não existia — violações das Leis 3 e 4.

### Fix aplicado

- `plan-roadmap` Fase 1: bloco de sinalização explícita dos artefatos encontrados/ausentes antes de prosseguir
- `ship-feature` Passo 0: aviso `⚠️` explícito quando `plan.md` não existe, antes de continuar sem checklist de infra

### Arquivos-chave

- `~/.claude/commands/plan-roadmap.md` — Fase 1
- `.claude/commands/ship-feature.md` — Passo 0

---

## [feat] Skills tab + Worktrees tab com orientação de workflow por agente — 2026-03-04

**Tipo:** feat
**Tags:** ui, skills, worktrees, session-manager
**PR:** [#35](https://github.com/rmolines/claude-terminal/pull/35) · **Complexidade:** alta

### O que mudou

O app agora tem duas novas abas: **Skills** (mostra a fase do workflow de cada agente ativo e as próximas
1-3 skills recomendadas com botão copy) e **Worktrees** (lista worktrees com branch dropdown no header).

### Detalhes técnicos

- `WorkflowPhase.swift` — enum de fases (strategic/featureActive/readyToShip/unknown) + `SkillDefinition` com todas as skills do sistema
- `GitStateService.swift` — actor async para git queries sem bloquear atores; polling 15s via `.task {}`
- `AgentWorkflowCard.swift` — card SwiftUI por sessão com fase detectada + próximos passos + copy buttons
- `SkillsNavigatorView.swift` — view principal da aba Skills
- `WorktreesView.swift` — aba Worktrees + branch dropdown no header
- `SessionStore`/`SessionManager` — fix: sessões externas (sem `CLAUDE_TERMINAL_MANAGED=1`) ignoradas; evict de sintéticas quando hook real chega

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Features/Skills/WorkflowPhase.swift` — data layer de skills
- `ClaudeTerminal/Features/Skills/SkillsNavigatorView.swift` — aba Skills
- `ClaudeTerminal/Services/GitStateService.swift` — git queries async
- `ClaudeTerminal/Features/Terminal/MainView.swift` — TabView atualizado

---

## [chore] Substituir /refine-idea por /explore no workflow — 2026-03-04

**Tipo:** chore
**Tags:** workflow, skills, docs
**PR:** [kickstart #12](https://github.com/rmolines/claude-kickstart/pull/12) · **Complexidade:** simples

### O que mudou

`/refine-idea` removido do fluxo — substituído por `/explore` (skill global mais poderosa).
Fluxo visual ganhou bloco EXPLORAÇÃO separado antes de ESTRATÉGICO em ambos os repos.

### Detalhes técnicos

- `.claude/rules/workflow.md` atualizado em claude-terminal e claude-kickstart
- Tabela de skills: `/explore` (deep) + `/explore --fast` (scan rápido) no lugar de `/refine-idea`
- PR #12 mergeado no kickstart

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/rules/workflow.md` — fluxo visual + tabela de skills

---

## [fix] HITL popups suprimidos para sessões externas — 2026-03-04

**Tipo:** fix
**Tags:** hitl, hooks, ipc
**PR:** [#33](https://github.com/rmolines/claude-terminal/pull/33) · **Complexidade:** simples

### Problema

O app mostrava popups de aprovação HITL para **qualquer** sessão do Claude Code na
máquina — inclusive sessões abertas no iTerm — porque o hook `PermissionRequest` é
global (`~/.claude/settings.json`). O usuário era interrompido por sessões que não
tinham relação com o app.

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

## [feat] Terminal-first UI — app abre direto com `claude` embedded — 2026-03-04

**Tipo:** feat
**Tags:** ui, terminal, cleanup
**PR:** [#31](https://github.com/rmolines/claude-terminal/pull/31) · **Complexidade:** média

### O que mudou

O app agora abre direto com um terminal rodando `claude` — sem dashboard, sem onboarding, sem ruído visual. Header minimalista com o diretório atual e botão para trocar de pasta.

### Detalhes técnicos

- Nova `MainView`: header com path + "Open Folder…" + PTY embedded via `TerminalViewRepresentable`
- `COLORTERM=truecolor` adicionado ao ambiente do PTY — cores vibrantes (fix vs iTerm)
- Remove 28 arquivos: DashboardView, AgentCardView, onboarding, skill registry, task backlog, views de quick-terminal/agent, schemas SwiftData V1-V3, models não usados
- Backend (HookIPCServer, SessionManager, NotificationService, SessionStore) mantido intacto

### Impacto

- **Breaking:** Não — somente UI. Backend e IPC inalterados.

### Arquivos-chave

- `ClaudeTerminal/Features/Terminal/MainView.swift` — nova view principal (criado)
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — usa MainView, removeu SwiftData e WindowGroups extras

---

## [feat] HITL floating NSPanel over all windows — 2026-03-03

**Tipo:** feat
**Tags:** hitl, appkit, nspanel, ux
**PR:** [#30](https://github.com/rmolines/claude-terminal/pull/30) · **Complexidade:** simples

### O que mudou

O painel de aprovação HITL agora aparece flutuante sobre qualquer janela ativa — incluindo
apps externos como Xcode, Finder ou navegadores — sem precisar trazer o Claude Terminal
para o primeiro plano. Antes, os controles Approve/Reject ficavam embutidos no card do agente.

### Detalhes técnicos

- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — novo controller `@MainActor`
  que gerencia um `NSPanel` com `level = .floating`, `collectionBehavior = [.canJoinAllSpaces,
  .fullScreenAuxiliary]`, `hidesOnDeactivate = false`, `isReleasedWhenClosed = false`
- Observa `SessionStore.sessions` via `withObservationTracking` — show/dismiss automático
- Reutiliza `HITLPanelView` existente via `NSHostingView` com callbacks approve/reject
- `ClaudeTerminal/App/AppDelegate.swift` — +3 linhas para instanciar e iniciar o controller

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — controller do panel
- `ClaudeTerminal/App/AppDelegate.swift` — ponto de entrada

---

## [feat] UX design system — identity, patterns, screens + design-review skill — 2026-03-03

**Tipo:** feat
**Tags:** ux, design, skills, documentation
**PR:** [#29](https://github.com/rmolines/claude-terminal/pull/29) · **Complexidade:** média

### O que mudou

Sistema de invariantes de UX: três arquivos de spec que Claude lê antes de qualquer trabalho de design,
mais a skill `/design-review` com três modos — revisão de view, intake de nova tela e auditoria holística do app.

### Detalhes técnicos

- `.claude/ux-identity.md` — modelo mental + 5 constraints operacionais (C1-C5)
- `.claude/ux-patterns.md` — 8 padrões codificados com When/Then/Because/Screens
- `.claude/ux-screens.md` — contratos de 10 telas (Job/Data/Entry/Exit/Open items)
- `.claude/commands/design-review.md` — skill com detecção de modo automática:
  - Argumento existente → revisão normal (RenderPreview + drift check + constraint audit)
  - Argumento novo → intake mode (entrevista estruturada → proposta de contrato)
  - `--holistic` → mapa de navegação + matriz padrões × telas + auditoria sistêmica C1-C5
- `CLAUDE.md` — spec files adicionados à tabela de hot files + seção de workflow de design

### Impacto

- **Breaking:** Não

### Arquivos-chave

- `.claude/commands/design-review.md` — skill principal
- `.claude/ux-identity.md`, `.claude/ux-patterns.md`, `.claude/ux-screens.md` — spec files

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

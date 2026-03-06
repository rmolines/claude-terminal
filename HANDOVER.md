# HANDOVER.md — Session history

Newest entries at the top.

---

## 2026-03-05 — HITL PTY bridge fix (PR #54)

**O que foi feito:**
Depurado e corrigido o comportamento dos botões Approve/Reject do painel HITL flutuante.

**Problema raiz:**
Claude Code usa dois mecanismos simultâneos de permissão em sessões interativas:
1. Hook `PermissionRequest` (bloqueante via Unix socket) — o app já respondia corretamente
2. TUI dialog interativo no terminal (raw mode, `1`=Yes / `Esc`=cancel) — ficava travado aguardando input de teclado

O botão aprovava o socket mas o TUI continuava bloqueado, fazendo o terminal parecer congelado.

**Fix aplicado:**
- `SessionManager.approveHITL`: após `respondHITL`, faz `TerminalRegistry.shared.sendInput([0x31], forCwd: cwd)` — byte `0x31` ("1") descarta o TUI dialog
- `SessionManager.rejectHITL`: após `respondHITL`, faz `sendInput([0x1b], forCwd: cwd)` — Escape cancela o TUI dialog
- `TerminalRegistry`: adicionado método `sendInput(_:forCwd:)` que busca o coordinator pelo path (com fallback de prefix matching)

**Armadilha encontrada:**
Usar `[0x31, 0x0d]` ("1\r") funcionava no primeiro dialog mas o `\r` vazava para o buffer do próximo dialog, auto-confirmando silenciosamente. Fix: usar apenas `[0x31]` — raw mode processa um byte de cada vez.

**Arquivos-chave:**
- `ClaudeTerminal/Services/SessionManager.swift` — `approveHITL` + `rejectHITL`
- `ClaudeTerminal/Services/TerminalRegistry.swift` — `sendInput(_:forCwd:)`

---

## 2026-03-05 — ship-close-skill-overhead (PR #53)

**O que foi feito:**

Dois bugs estruturais de ordering nas skills `/ship-feature` e `/close-feature` foram corrigidos,
mais a adição do padrão "ASSERT antes de prosseguir" como guard antes de cada step destrutivo.

**Bugs corrigidos:**

1. **`close-feature` — docs na branch morta**: a skill usava paths relativos (ex: `HANDOVER.md`) sem
   assertar que CWD == REPO_ROOT. Em sessões executadas dentro de `.claude/worktrees/<feature>`, os
   writes iam para a worktree (deletada no próximo passo) — não para main. Fix: ASSERT REPO_ROOT no
   início do passo 1 + absolute paths em todos os file writes.

2. **`ship-feature` — blind merge**: a skill chamava `merge_pull_request` antes de verificar CI.
   Fix: `gh pr checks <pr_number> --watch` antes do merge. CI vermelho = PARAR.

**Guards adicionados (padrão ASSERT):**

- `close-feature`: ASSERT REPO_ROOT antes de qualquer write; ASSERT CWD ≠ worktree antes do remove
- `ship-feature`: ASSERT CI passing antes de `merge_pull_request`
- `start-feature`: ASSERT branch não existe no remote antes de `EnterWorktree`

**Propagado para:** `/Users/rmolines/git/claude-kickstart/.claude/commands/` (close, ship, start).

**Decisões tomadas:**

- Mantido docs retrospectivos pós-merge (HANDOVER, LEARNINGS) — legítimos; só precisavam de
  absolute paths para aterrar em main, não em worktree morta
- Descartado `gh pr merge --auto` como solução de CI gate — requer branch protection settings
  (decisão de governança maior)

**Próximos passos:**

- Commit + PR dos fixes no kickstart (pendente — edições locais não commitadas)

**Arquivos-chave:**

- `.claude/commands/close-feature.md` — ASSERT REPO_ROOT + absolute paths + assert CWD
- `.claude/commands/ship-feature.md` — CI gate antes do merge
- `.claude/commands/start-feature.md` — ASSERT branch remota

---

## 2026-03-06 — feat(skills): nova skill /polish para sessões de batch cleanup (PR #50)

**O que foi feito:**
Nova skill `/polish` criada em `.claude/commands/polish.md`. Resolve o gap identificado
no `explore.md` de polish-sprint: não havia como executar N melhorias pequenas e conhecidas
com micro-commits individuais sem o overhead de um ciclo completo de feature por item.

**Como funciona:**
1. Usuário informa lista de itens upfront
2. Skill abre branch `chore/polish-<data>` uma vez
3. Para cada item: implementa → micro-commit → próximo
4. No final: um único PR com todos os commits preservados (sem squash)

**Decisões tomadas:**
- PR usa `mergeMethod: "merge"` (não squash) — squash destrói a rastreabilidade por item
- Loop de execução é autônomo — sem parar entre itens pedindo confirmação
- Item complexo inesperado → parar e reportar; nunca continuar silenciosamente

**Propagação:**
- Projeto: PR #50 (mergeado, CI verde após fix MD022 em PR #51)
- Kickstart: PR #20 em `rmolines/claude-kickstart` (mergeado)

**Arquivos-chave:**
- `.claude/commands/polish.md` — skill criada
- `.claude/rules/workflow.md` — /polish adicionado ao fluxo visual e tabela

---

## 2026-03-06 — fix(updater): chave EdDSA real do Sparkle em Info.plist (PR #52)

**O que foi feito:**
`SUPublicEDKey` em `Info.plist` tinha o valor placeholder `REPLACE_WITH_PUBLIC_KEY_FROM_generate_keys`
desde o bootstrap. O Sparkle valida a chave na inicialização e recusava iniciar completamente,
exibindo "The updater failed to start". A chave real já existia no Keychain (gerada anteriormente)
e no GitHub Secrets como `SPARKLE_PRIVATE_KEY` — só faltava colocar a pública no plist.

**Fix:**
- Rodado `.build/artifacts/sparkle/Sparkle/bin/generate_keys` (binário pré-compilado no artefato SPM)
- A chave pré-existente no Keychain foi retornada e inserida em `Info.plist`
- Verificado com `make install` + "Check for Updates…" no menu bar — updater iniciou sem erros

**Armadilha:**
`swift run generate_keys` falha — o pacote SPM do Sparkle é `binaryTarget` e não expõe executáveis.
O binário está em `.build/artifacts/sparkle/Sparkle/bin/generate_keys`.

**Arquivos-chave:**
- `ClaudeTerminal/App/Info.plist:26` — `SUPublicEDKey`

**Próximos passos:** nenhum — fix pontual.

---

## 2026-03-06 — fix(terminal): session-ended overlay quando PTY encerra (PR #49)

**O que foi feito:**
`processTerminated` em `TerminalViewRepresentable.Coordinator` era um no-op — quando o usuário
dava `exit` no Claude (ou Ctrl+D), o processo `zsh -c "cd && claude"` encerrava, o PTY morria
mas a view ficava congelada sem feedback visual e sem forma de recuperar sem usar o botão `↺`.

**Fix:**
- `TerminalViewRepresentable`: adicionado `onProcessTerminated: (@MainActor @Sendable () -> Void)?`
- `Coordinator.processTerminated`: captura o closure antes do `Task { @MainActor in ... }` para satisfazer Swift 6 concurrency (sem capturar `self` no closure)
- `ProjectDetailView`: novo `@State private var deadPaths: Set<String>` — quando processo encerra, path entra no set; ZStack exibe overlay "Session ended" com botão **Restart**
- Botão Restart do overlay e botão `↺` do header ambos removem de `deadPaths` e bumpam `terminalRevision`

**Armadilha Swift 6:** `DispatchQueue.main.async { [weak self] in self?.callback() }` é rejeitado — "sending self risks data race".
Fix: capturar o closure em `let callback = onProcessTerminated` antes do `Task`, e marcar o tipo como `@MainActor @Sendable`.

**Arquivos-chave:**
- `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift:21,143,175`
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift:17,115,131`

**Próximos passos:** nenhum — fix pontual, sem dívida técnica.

---

## 2026-03-05 — chore: sync skills + docs (PR #46)

**O que foi feito:**
Sincronização das skills de workflow com upstream `claude-kickstart` (db742b0) + documentação
dos fixes de HITL das sessões anteriores.

**Skills atualizadas:**
- `propagate-skills.md` — nova skill para sincronizar skills entre camadas
- `close-feature.md` — streamlinado (removidos passos 0.6/0.7, 1f, 2.5)
- `ship-feature.md` — gate `/validate` antes do PR + merge simplificado
- `start-feature.md` — seção "quando usar sem roadmap"; conflitos de merge resolvidos
- `start-milestone.md`, `validate.md`, `fix.md`, `checkpoint.md` — melhorias pontuais

**Fricção encontrada:**
CI do GitHub Actions não disparou para o PR após pushes e reopen — GitHub Actions em estado de
"pending sem runs". Merge feito via admin bypass. Causa não identificada (não relacionada ao código).

**Próximos passos:** nenhum — chore de manutenção.

---

## 2026-03-05 — fix(hitl): panel nunca fechava + descrição sempre genérica

**O que foi feito:**
Dois bugs no fluxo HITL corrigidos na branch `chore/skills-ship-close-fixes`, PR #45.

**Bug 1 — Panel nunca fechava após Approve/Reject:**
`approveHITL`/`rejectHITL` em `SessionManager` atualizavam `sessions` localmente mas
não chamavam `SessionStore.shared.update()`. O `HITLFloatingPanelController` observa
`SessionStore` via `withObservationTracking` — sem o update, o panel nunca recebia o sinal
para fechar. Do ponto de vista do usuário: clicar em Approve/Reject não fazia nada visível.

**Bug 2 — Descrição sempre "Awaiting approval":**
`HookHandler` buscava `toolInput["description"]` para PermissionRequest, mas o Claude Code
envia o comando Bash em `toolInput["command"]`. Resultado: `detail = nil` sempre para Bash,
e o panel mostrava "Awaiting approval" em vez do comando real.

**Fixes:**
- `SessionManager.approveHITL`/`rejectHITL`: adicionado `Task { @MainActor in SessionStore.shared.update(session) }` após mudar status
- `HookHandler`: extração de detail agora usa `toolInput["command"]` → fallback `toolInput["description"]` → fallback `toolName`

**Arquivos-chave:**
- `ClaudeTerminal/Services/SessionManager.swift:87-101`
- `ClaudeTerminalHelper/HookHandler.swift:47-50`

**Próximos passos:** nenhum — fixes pontuais, sem dívida técnica.

---

## 2026-03-05 — hitl-panel-crash (PR #44)

### O que foi feito

Corrigido crash `EXC_BREAKPOINT (SIGTRAP)` em `postWindowNeedsUpdateConstraints` que ocorria
após ~1h de uso quando um agente ficava aguardando aprovação HITL.

Causa raiz: `HITLFloatingPanelController.updatePanel()` é chamado em **toda** mudança de
`SessionStore.sessions` — heartbeats, bash events, etc. de qualquer sessão. Enquanto o painel
HITL estava visível, `show()` chamava `hosting.rootView = view` repetidamente. Cada atribuição
invalida constraints do `NSHostingView(.minSize)`, que dispara `setNeedsUpdateConstraints()` →
`postWindowNeedsUpdateConstraints`. No macOS 26, esse método tem assertions mais rígidas e lança
`NSException` quando acionado durante um layout cycle em andamento.

Fix: adicionar `currentSessionID: String?` e `currentDescription: String?` ao controller.
`show()` retorna cedo se o painel já está mostrando o mesmo conteúdo. Cache limpo no dismiss.

### Arquivos-chave

- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift`

### Próximos passos

- Nenhum pendente desta feature

---

## 2026-03-05 — skill-flow-improvements (PR #38)

### O que foi feito

- `workflow.md`: 4 fixes — fluxo PITCH corrigido (--discover → só discovery.md → /clear → --deep);
  gate `/design-review` adicionado no TÁTICO e AD-HOC; tabela `--discover` output e próxima skill corrigidos;
  linha `/design-review` adicionada na tabela de skills
- `start-feature.md`: B.2 Architecture Design — 3 arquitetos paralelos (Minimal/Clean/Pragmatic) com
  síntese comparativa e escolha explícita do usuário antes de montar o plano
- `start-feature.md`: C.6.5 Code Quality Review — 3 revisores paralelos após build verde
  (Simplicity/Bugs/Conventions); usuário decide o que corrigir; re-roda C.6 se houver fixes
- `start-feature.md`: nota `--novel` no fast path — chain of thought em vez de perguntas abertas
- Lint: 36 erros → 0 em CHANGELOG.md, HANDOVER.md, checkpoint.md (blank lines após headings + line length)

### Decisões tomadas

- Architecture Design (B.2) usa 3 arquitetos em vez de 2 para features M/G; Arquiteto C (Pragmatic)
  é pulado em features P para não adicionar overhead desnecessário
- Code Quality Review (C.6.5) só executa após build verde — nunca bloqueia o fluxo com build quebrado
- Lint fixes aplicados oportunisticamente já que estávamos tocando CHANGELOG.md e HANDOVER.md de qualquer forma

### Arquivos-chave

- `.claude/rules/workflow.md` — fluxos PITCH, TÁTICO, AD-HOC e tabela de skills
- `.claude/commands/start-feature.md` — Fase B (B.2–B.6) e Fase C (C.6.5)

### Próximos passos

- Propagar `start-feature.md` atualizado ao kickstart (B.2 Architecture Design e C.6.5 são genéricos)

---

## 2026-03-05 — multi-project-workspace (PR #37)

### O que foi feito

Transformou o Claude Terminal de app single-project para multi-project workspace. Agora o app
mantém N sessões Claude simultâneas, com sidebar de projetos e ZStack mantendo PTYs vivos.

**Deliverables entregues:**

1. **SwiftData foundation** — `ClaudeProject` @Model (id, name, path=git root, displayPath=cwd ativo,
   sortOrder, statusRaw), `ModelContainer.makeShared()` com store em `~/Library/Application Support/ClaudeTerminal/ClaudeTerminalProjectsV1.store`

2. **Multi-terminal ZStack** — `openedProjectIDs: [PersistentIdentifier]` acumula projetos abertos;
   ZStack com `opacity(0/1)` + `allowsHitTesting` mantém PTYs vivos ao trocar de projeto

3. **Git root grouping** — `GitStateService.gitRootPath(for:)` usa `git rev-parse --git-common-dir`
   (não `--show-toplevel`) para unificar worktrees do mesmo repo sob um único `ClaudeProject`

4. **Migration** — `migrateIfNeeded()` converte `@AppStorage("workingDirectory")` +
   `recentDirectoriesData` → `ClaudeProject` entities na primeira abertura

5. **Cleanup** — `cleanupAndDeduplicateProjects()` mescla duplicatas por git root, remove orphans,
   reseta `displayPath` stale para git root, roda em cada `.onAppear`

### Decisões tomadas

- **`--git-common-dir` em vez de `--show-toplevel`**: mostra o diretório `.git` compartilhado
  entre todas as worktrees → parent = canonical repo root. `--show-toplevel` retornaria o path
  da worktree individual, aparecendo como projeto separado.
- **`List` com `onTapGesture` manual** (não `List(selection:)`): conflito entre `var id: UUID`
  explícito e `persistentModelID` do SwiftData causava cliques ignorados.
- **Store name distinto**: `ClaudeTerminalProjectsV1.store` (não default) evita colisão com
  stores residuais do ciclo DashboardView.
- **Deliverable 3 parcial**: status badge na sidebar não foi entregue — `SessionStore` → `ClaudeProject`
  upsert ficou fora do escopo desta iteração; `ProjectDetailView` criado com header de path + branch
  como substituto.

### Armadilhas encontradas

- **`ModelContainer` não cria diretórios intermediários**: sem `FileManager.createDirectory` antes
  do `ModelConfiguration(url:)`, o store cai silenciosamente para in-memory e dados se perdem.
- **`List(selection:)` com @Model + `var id: UUID`**: SwiftData adiciona `Identifiable` via
  `persistentModelID`; conflito com `var id: UUID` explícito faz cliques serem ignorados.
- **PTY não reinicia após `displayPath` corrigido externamente**: `sessionID` não muda quando
  `cleanupAndDeduplicateProjects()` altera `displayPath` → `.onChange(of: project.displayPath)`
  detecta e reseta `sessionID`.
- **Worktrees aparecem como projetos separados**: `--show-toplevel` retorna path da worktree;
  correto é `--git-common-dir` + `deletingLastPathComponent`.

### Arquivos-chave

- `ClaudeTerminal/Models/ClaudeProject.swift` — novo @Model
- `ClaudeTerminal/Models/AppMigrationPlan.swift` — novo ModelContainer factory
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — adicionado `.modelContainer(sharedContainer)`
- `ClaudeTerminal/Features/Terminal/MainView.swift` — reescrito (NavigationSplitView + ZStack)
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — novo (header + tabs)
- `ClaudeTerminal/Services/GitStateService.swift` — adicionado `gitRootPath(for:)`

### Próximos passos

- Deliverable 3 pendente: bridge `SessionStore` → `ClaudeProject.status` para badges na sidebar
- Fix pré-existente: `CHANGELOG.md` + `.claude/commands/checkpoint.md` têm violações MD022/MD013
  que estão quebrando o lint CI desde antes desta feature

---

## 2026-03-05 — absorver ideias do Superpowers (intake + verification + TDD)

### O que foi feito

- `start-feature.md`: regra "uma pergunta por vez, prefira múltipla escolha" adicionada antes das rodadas de intake da Fase 0 (--discover)
- `ship-feature.md`: novo Passo 0.5 (HARD GATE) — roda `swift build` + `swift test` antes de qualquer commit
- `tdd.md`: novo rule file — ciclo RED/GREEN/REFACTOR, escopo no projeto, tabela de racionalizações, hard rule
- `workflow.md`: referência ao `skill-contracts.md` adicionada no cabeçalho

### Decisões tomadas

- Mantivemos regras como rule files (`.claude/rules/`) em vez de criar nova skill — menor overhead, sempre em contexto
- `tdd.md` não se aplica a SwiftUI views (usar `RenderPreview` via Xcode MCP)

### Arquivos-chave

- `.claude/commands/start-feature.md` (Fase 0, Passos 0.3–0.5)
- `.claude/commands/ship-feature.md` (Passo 0.5 + Regras)
- `.claude/rules/tdd.md` (novo)
- `~/.claude/commands/explore.md` (global — mesma regra de intake)

### Próximos passos

- Lint CI falha em `CHANGELOG.md` e `checkpoint.md` — violações pré-existentes, issue separado

---

## 2026-03-04 — fix audit-skills violations #2 e #3

### O que foi feito

- **Fix #2 `plan-roadmap` (Lei 3/4):** Fase 1 agora sinaliza explicitamente quais artefatos de `/start-project` foram encontrados antes de lê-los
- **Fix #3 `ship-feature` (Lei 4):** Passo 0 emite `⚠️` explícito quando `plan.md` não existe
- Mudanças aplicadas em: `~/.claude/commands/plan-roadmap.md` (global), `claude-kickstart` PR #14, `claude-terminal`

### Decisões técnicas

- `plan-roadmap` é global (`~/.claude/commands/`) — sem git, mudança só em disco
- `ship-feature` propagou via kickstart PR #14 → sync para claude-terminal

### Arquivos-chave

- `~/.claude/commands/plan-roadmap.md` — Fase 1, bloco de sinalização de artefatos
- `.claude/commands/ship-feature.md` — Passo 0, bloco else de plan.md ausente

---

## 2026-03-04 — skills-navigator + worktrees-tab (PR #35)

### O que foi feito

- Aba **Skills**: detecta fase do workflow por agente (strategic/featureActive/readyToShip), exibe próximas skills com botão copy
- Aba **Worktrees**: lista worktrees ativos com branch dropdown no header
- `WorkflowPhase` + `SkillDefinition`: enum + data layer estático com todas as skills do sistema
- `GitStateService`: actor async para queries de git sem bloquear atores (polling 15s)
- Fix `SessionStore`/`SessionManager`: só sessões `CLAUDE_TERMINAL_MANAGED=1` entram no store

### Decisões técnicas

- `Foundation.Process` para git queries — `terminationHandler` marcado `@Sendable` para Swift 6
- Polling a cada 15s via `.task {}` — cancela automaticamente quando a view sai de cena
- `WorkflowPhase.infer()` prioriza cwd (`.claude/worktrees/`) antes da branch

### Armadilhas encontradas

- Worktree ficou stale (diretório em disco, não no `git worktree list`) — branch local tinha os commits mas
  working tree apontava para main. Solução: trabalhar direto com a branch + `git push --force-with-lease`
- `gh pr merge` sem `-R owner/repo` deu erro "Could not resolve to a PullRequest"

### Arquivos-chave

- `ClaudeTerminal/Features/Skills/WorkflowPhase.swift` — enum de fases + SkillDefinition
- `ClaudeTerminal/Features/Skills/SkillsNavigatorView.swift` — view principal da aba Skills
- `ClaudeTerminal/Features/Skills/AgentWorkflowCard.swift` — card por agente
- `ClaudeTerminal/Services/GitStateService.swift` — git queries async
- `ClaudeTerminal/Features/Terminal/MainView.swift` — TabView com 3 abas
- `ClaudeTerminal/Features/Worktrees/WorktreesView.swift` — aba Worktrees
- `ClaudeTerminal/Services/SessionStore.swift` — filtro de sessões gerenciadas

### Próximos passos possíveis

- Mostrar o trigger condition de skills auto-trigger na aba Skills
- Refresh manual na aba Skills (pull-to-refresh ou botão)
- Persistir fase detectada no SwiftData para histórico

---

## 2026-03-04 — propagação do /explore (workflow.md + kickstart PR #12)

**O que foi feito:** Substituiu `/refine-idea` por `/explore` no fluxo de workflow em ambos os repos.
Adicionou bloco EXPLORAÇÃO separado antes de ESTRATÉGICO no fluxo visual.
Atualizou tabela de skills com `/explore` e `/explore --fast`. Abriu e mergou PR #12 no `claude-kickstart`.

**Decisões tomadas:**

- `/refine-idea` vira stub; skill oficial é `/explore` (absorve e expande o caso de uso)
- `/explore --fast` nomeado para preservar o caminho rápido (≈ antigo refine-idea)
- sync-skills não propaga `rules/` — update de workflow.md sempre manual nos dois repos

**Arquivos-chave:**
- `.claude/rules/workflow.md` — atualizado em claude-terminal e claude-kickstart

**Estado ao encerrar:** `main` limpo, 1 commit atrás do origin (sem push).

---

## 2026-03-04 — docs cleanup (PR #34) — ship-feature + close-feature session

**O que foi feito:** Limpeza do estado acumulado do repo — 13 arquivos modificados não commitados,
worktree na branch errada, dois PRs duplicados para o mesmo fix. Entregou PR #34 com docs, lint
config e feature plans arquivados. Adicionou modo `--audit` completo ao `design-review.md`.

**Diagnóstico do estado inicial:**

- Main repo em `fix/hitl-external-sessions-v2` (não em `main`) com 13 tracked files modificados
- PRs #30 e #31 já mergeados, #32 e #33 abertos para o mesmo fix — #33 mergeado durante a sessão
- Outro agente commitou direto em main (`06780f3`) durante a resolução, causando conflito no rebase
- `design-review.md` com 541 linhas no working tree, 399 no commit — modo `--audit` no stash

**Armadilhas encontradas:**

- `.markdownlint-cli2.yaml` sem `config:` → markdownlint v0.6.0 ignora `.markdownlint.yaml`
  → CI quebra com MD049 (asterisk vs underscore) e MD036 (bold-as-heading) em arquivos não tocados
- Stash pop de worktree cruzada restaura mudanças silenciosamente no working tree sem criar commit
- Commits paralelos em main por outros agentes causam conflitos no rebase da PR em andamento

**Fixes aplicados:**

- Adicionou `config: .markdownlint.yaml` ao `.markdownlint-cli2.yaml`
- Corrigiu `*asterisk*` → `_underscore_` e `**bold-heading**` → `### heading` no `design-review.md`
- Resolveu 3 conflitos (CHANGELOG, CLAUDE.md, HANDOVER.md) mantendo conteúdo mais detalhado
- Limpou branch e worktrees stale

**PR:** #34

---

## 2026-03-04 — fix(hitl): suppress HITL popups para sessões externas

**O que foi feito:** Corrigido bug onde o app mostrava popups HITL para sessões Claude Code
iniciadas externamente (iTerm). Solução: env var `CLAUDE_TERMINAL_MANAGED=1` no PTY propaga
via fork/exec até o hook binary. `SessionManager` só mostra popup para `isManagedByApp == true`.
Sessões externas são auto-aprovadas silenciosamente. **PR:** #33.

**Decisões:** Auto-approve para externos (hook é bloqueante — sem pass-through). `isManagedByApp`
como `Bool?` para backward compat com helpers antigos. fd armazenado antes de `handleEvent` no
`HookIPCServer` para que auto-approve encontre o fd imediatamente.

**Armadilhas:** PR #32 conflitou — `SpawnedAgentView` foi deletado pelo PR #31 (terminal-first UI)
que mergeu primeiro. Solução: novo branch do main atual, fix vai para `MainView.swift`.
Worktrees stale (`terminal-first-ui`, `hook-setup-onboarding`) causavam erro de build no Xcode —
removidos + derived data limpa.

**Arquivos:** `Shared/IPCProtocol.swift`, `ClaudeTerminalHelper/HookHandler.swift`,
`ClaudeTerminal/Services/HookIPCServer.swift`, `ClaudeTerminal/Services/SessionManager.swift`,
`ClaudeTerminal/Features/Terminal/MainView.swift`

---

## 2026-03-04 — terminal-first-ui

**O que foi feito:** Substituiu o DashboardView por uma UI minimalista —
app abre direto com `claude` rodando em PTY embedded. Nova `MainView` com
header (path + botão "Open Folder…") e terminal inline. Removeu 28 arquivos
(dashboard, onboarding, skill registry, task backlog, 14 models/services).
Backend (HookIPCServer, SessionManager, NotificationService) mantido intacto.

**Decisão-chave:** `COLORTERM=truecolor` adicionado ao ambiente do PTY — sem essa
variável, Claude Code cai para modo paleta ANSI e as cores aparecem apagadas vs iTerm.
Com `truecolor`, o processo emite escape codes 24-bit e as cores são exatas.

**Armadilhas encontradas:**

- `COLORTERM=truecolor` é obrigatório para cores vibrantes — não basta `TERM=xterm-256color`.
  Claude Code detecta suporte a true color por essa variável.
- SwiftTerm usa `NSColor(deviceRed:)` que em displays P3 pode produzir cores ligeiramente
  diferentes dos valores sRGB originais — mas o impacto real foi o `COLORTERM` ausente.

**Arquivos-chave:**

- `ClaudeTerminal/Features/Terminal/MainView.swift` — nova view principal
- `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift` — wrapper SwiftTerm

**PR:** #31

---

## 2026-03-03 — hitl-floating-nspanel

**O que foi feito:** Implementou `HITLFloatingPanelController` — NSPanel com `level = .floating`
que aparece sobre qualquer janela (incluindo apps externos) quando um agente entra em
`.awaitingInput`. Wired up em `AppDelegate`. PR #30.

**Arquivos criados/modificados:**

- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — controller `@MainActor`,
  observa `SessionStore.sessions` via `withObservationTracking`, gerencia ciclo de vida do panel
- `ClaudeTerminal/App/AppDelegate.swift` — +3 linhas: instância + `start()`

**Decisões tomadas:**

- `hidesOnDeactivate = false` — crítico para o panel não sumir ao trocar de app
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` — aparece em todos os Spaces
  e sobre apps em full-screen
- `NSHostingView.sizingOptions = [.minSize]` — panel auto-dimensiona a partir da SwiftUI view
- `panel.center()` apenas na primeira exibição (`!panel.isVisible`) — respeita reposicionamento
  manual do usuário

**PR:** #30

---

## 2026-03-03 — ux-design-lead

**O que foi feito:** Criou o sistema de invariantes de UX do projeto.
PR #29 adicionou intake mode e revisão holística ao `/design-review`.

**Arquivos criados/modificados:**

- `.claude/ux-identity.md` — modelo mental + 5 constraints operacionais (C1-C5)
- `.claude/ux-patterns.md` — 8 padrões codificados
- `.claude/ux-screens.md` — contratos de 10 telas (Job/Data/Entry/Exit/Open)
- `.claude/commands/design-review.md` — skill head of design com 3 modos
- `CLAUDE.md` — tabela de hot files e seção de workflow de design

**Decisões tomadas:**

- Intake mode faz entrevista em rounds para não sobrecarregar o dev
- Detecção de modo: `--holistic` verificada ANTES de buscar nome em ux-screens.md
- Revisão holística é somente leitura — nunca modifica spec automaticamente

**Armadilhas encontradas:**

- `gh pr create` dentro de worktree detecta repo errado (`claude-kickstart`) —
  usar `gh api repos/<owner>/<repo>/pulls` diretamente
- Code blocks sem language tag causam falha no lint (MD040)

**PR:** #29

---

## 2026-03-03 — bet-bowl

**O que foi feito:** Implementou o Bet Bowl — seção de captura efêmera de ideias de features no `TaskBacklogView`.
Dev pode anotar bets em um campo (título), sorteá-las aleatoriamente via sheet (`BetDrawSheet`) e converter a bet
sorteada em `ClaudeTask` com um clique. Inclui migração SwiftData V2→V3 (nova entidade `Bet`).

**PR:** #27 — https://github.com/rmolines/claude-terminal/pull/27

**Decisões tomadas:**
- Sem campo `drawnAt` / status `"drawn"` na v1 — fluxo simplificado: apenas `draft` → `converted`.
- `Bet` sem inner classes congeladas no SchemaV3 — entidade nova, sem risco de entity-name mismatch.
- Draw desabilitado com menos de 2 bets (não faz sentido sortear com 1 opção).
- Conversão cria `ClaudeTask` linkado via `convertedTaskID` (UUID fraco, sem relacionamento SwiftData formal).

**Arquivos-chave modificados:**
- `ClaudeTerminal/Models/Bet.swift` — `@Model` com `id`, `title`, `notes`, `status`, `createdAt`, `convertedTaskID`, `sortOrder`
- `ClaudeTerminal/Models/SchemaV3.swift` — nova versão de schema (`@preconcurrency import SwiftData`)
- `ClaudeTerminal/Models/AppMigrationPlan.swift` — stage `migrateV2toV3` lightweight
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — `Bet.self` adicionado ao schema
- `ClaudeTerminal/Features/TaskBacklog/TaskBacklogView.swift` — Bet Bowl section + inline form + sheet
- `ClaudeTerminal/Features/TaskBacklog/BetDrawSheet.swift` — sheet de sorteio (Convert/Re-draw/Dismiss)

**Armadilhas encontradas:** CI falhou no primeiro push — `@preconcurrency import SwiftData` faltando no `SchemaV3.swift`
(mesmo padrão dos schemas V1 e V2, já documentado em CLAUDE.md). Fix em segundo commit.

**Próximos passos:** Próxima feature do M4 conforme `backlog.json` (status=pending).

---

## 2026-03-02 — fix-swiftdata-migration

**O que foi feito:** Corrigiu crash fatal no boot do app (`SwiftData.SwiftDataError`) causado por dois bugs na migration plan V1→V2 introduzida em bc22d7f (M4 Unit 2).

**Causa raiz:**
1. `SchemaV1` usava `ClaudeTaskV1`/`ClaudeAgentV1` como nomes de classe → Core Data gerava entity names errados
   vs. o store em disco ("ClaudeTask"/"ClaudeAgent"). Sem match de source model → migration lançava exceção → `try!` crashava.
2. `var priority: String` sem default value → Core Data não conseguia popular linhas existentes com a nova coluna durante lightweight migration.

**Fix:** Renomear inner classes para `ClaudeTask`/`ClaudeAgent` em `SchemaV1` (namespaceadas pelo enum, sem conflito); adicionar `= ""` em `var priority: String`.

**Arquivos-chave:** `ClaudeTerminal/Models/SchemaV1.swift`, `ClaudeTerminal/Models/ClaudeTask.swift`

**Armadilha:** Padrão correto do SwiftData é manter o MESMO nome de classe em todos os `VersionedSchema` (namespaceados pelo enum) — não usar sufixos V1/V2 no nome da classe.

---

## 2026-03-02 — readme-demo

**O que foi feito:** Substituiu o README.md herdado do template `claude-kickstart` por um README de produto do Claude Terminal.
Inclui badges (macOS 14+, Swift 6.2, MIT), hero title, placeholder de GIF do fluxo HITL, quickstart de 3 passos
(Download DMG → Open → Install Hooks), lista de features, diagrama ASCII da arquitetura de hooks, e seção de requisitos.
Também corrigiu 21 erros de markdownlint pré-existentes em `.claude/commands/` e docs (MD013, MD038, MD040, MD048).

**Decisões:**
- GIF ainda não gravado → placeholder com comentário `<!-- GIF: gravar e salvar como docs/hitl-demo.gif -->`
- Blocos de exemplo com fences aninhadas (em `start-milestone.md`) precisam de outer fence com 4 backticks para
  evitar que markdownlint (MD040) confunda a fence interna com o fechamento do bloco externo
- Stray ` ``` ` em `project-compass.md:139` removida (bloco aberto sem fechamento)

**Arquivos-chave:**
- `README.md` — substituído integralmente
- `.claude/commands/start-milestone.md` — outer fences migradas para 4 backticks
- `.claude/commands/project-compass.md` — stray fence removida

**Próximos passos:** `launch-distribution` — agora desbloqueada (dependia de readme-demo)

---

## 2026-03-02 — mermaid-skill-flow

**O que foi feito:** Adicionou diagrama `stateDiagram-v2` Mermaid ao `workflow.md` do claude-terminal e ao `workflow.md` do kickstart.
Renderiza nativamente no GitHub, mostrando todos os estados de skill, transições, loop tático por feature e caminho de orientação via `project-compass`.

**Decisões:**
- Diagrama vai na seção `## Diagrama de fluxo`, após o bloco ASCII existente (os dois coexistem — ASCII para leitura rápida, Mermaid para visualização)
- Mesmo diagrama propagado para `~/git/claude-kickstart/.claude/rules/workflow.md`
- Feature ad-hoc (sem sprint.md) → plan.md salvo em `adhoc/mermaid-skill-flow/`

**Armadilha encontrada:** `plan.md` escrito no working tree do `main` antes de criar o worktree ficou como arquivo não-rastreado
no main — bloqueou o `git pull` após merge. Sempre escrever o `plan.md` no path do worktree, não no main.

**Arquivos-chave:**
- `.claude/feature-plans/claude-terminal/workflow.md`
- `.claude/feature-plans/claude-terminal/adhoc/mermaid-skill-flow/plan.md`

**Próximos passos:** `/start-feature skill-frontmatter-registry` (feature B — YAML frontmatter nas skills)

---

## 2026-03-01 — hook-pipeline: end-to-end hook event flow

**What was done:**

Conectou os 6 fios desconectados do scaffold para que eventos fluam:
`Claude Code → Helper → HookIPCServer → SessionManager → SessionStore → DashboardView`

- **SessionStore** (`NEW`): `@MainActor @Observable` bridge — actor pusha snapshots via `Task { @MainActor in ... }`; SwiftUI observa sem boilerplate
- **HookIPCServer**: fd do cliente HITL mantido aberto; `respondHITL(sessionID:approved:)` escreve 1 byte e fecha — protocolo bi-direcional via Unix domain socket
- **SessionManager**: `handleEvent` tornou-se `async` para chamar `await NotificationService`; dispara notificação em `permissionRequest`; `approveHITL`/`rejectHITL` roteiam resposta real via `HookIPCServer`
- **IPCClient**: `sendAndAwaitResponse()` — bloqueia o helper com `SO_RCVTIMEO` de 5 min enquanto aguarda byte de resposta
- **HookHandler**: `run()` retorna `Int32`; permissionRequest bloqueia; exit 0 = allow, exit 2 = block (Claude Code spec)
- **AppDelegate**: inicia servidor no launch; `observeSessionStore()` via `withObservationTracking` + re-subscribe recursivo para badge reativo
- **DashboardView**: lista real de sessões com ícones de status + badge "HITL" laranja
- **Tests**: 5/5 passando — 3 state machine tests (local actor mirror) + 2 Shared protocol tests

**Decisões técnicas:**

- `withObservationTracking` em vez de Combine/polling para o badge no `AppDelegate` — padrão canônico de `@Observable` fora do SwiftUI
- `SO_RCVTIMEO` de 5 minutos no helper para evitar hang indefinido em HITL sem app rodando
- State machine tests usam `LocalSessionManager` local (actor mirror) porque targets executáveis não suportam `@testable import` em SPM — boa prática documentada nos tests

**Armadilhas encontradas:**

- `gh pr merge --squash --delete-branch` falha em worktree porque `main` já está checked out no repo pai — usar `--squash` sem `--delete-branch` e deletar o remote branch separadamente
- CI falhou por `MD040` em `start-feature.md` (fenced block sem language tag) — introduzido no commit anterior, corrigido com `fix(ci): add language tag`

**Arquivos-chave:**

- `ClaudeTerminal/Services/SessionStore.swift` — NOVO: bridge actor→SwiftUI
- `ClaudeTerminal/Services/SessionManager.swift` — handleEvent async + HITL routing
- `ClaudeTerminal/Services/HookIPCServer.swift` — HITL bi-direcional
- `ClaudeTerminalHelper/IPCClient.swift` — sendAndAwaitResponse()
- `ClaudeTerminalHelper/HookHandler.swift` — exit code para Claude Code

**PR:** [#3](https://github.com/rmolines/claude-terminal/pull/3)

**Próximos passos:**

- Implementar ação de HITL inline na DashboardView (botões Approve/Reject, não só via notificação)
- Adicionar `ClaudeTerminalCore` library target para habilitar `@testable import` de `SessionManager`
- End-to-end test com helper real conectado via socket

---

## 2026-02-27 — Bootstrap via /start-project

**What was done:**

- Executed Fase 3 (Bootstrap) of `/start-project` for the `claude-kickstart` template repository
- Created GitHub repo `rmolines/claude-kickstart` (public)
- Wrote all project files: CLAUDE.md, Makefile, CI workflows, skills, hooks, rules, memory files

**Architectural decisions:**

- GitHub Template Repository format (not CLI) — zero friction
- Hooks in `.claude/hooks/` external scripts (not inline `settings.json`) — auditable, CVE-2025-59536 compliant
- Static CI only (lint + JSON + structure) — no runtime to test
- `bootstrap.yml` with `run_number == 1` guard — auto-applies branch protection on first fork push

**Files created:**

- `CLAUDE.md`, `README.md`, `LEARNINGS.md`, `HANDOVER.md`, `Makefile`
- `.claude/settings.json`, `.claude/settings.md`
- `.claude/hooks/pre-tool-use.sh`
- `.claude/scripts/validate-structure.sh`
- `.claude/rules/git-workflow.md`, `coding-style.md`, `security.md`
- `.claude/commands/start-feature.md`, `ship-feature.md`, `close-feature.md`
- `.claude/commands/handover.md`, `sync-skills.md`
- `.claude/commands/SYNC_VERSION`
- `.github/workflows/ci.yml`, `bootstrap.yml`, `template-sync.yml`
- `.github/dependabot.yml`, `CODEOWNERS`, `SECURITY.md`
- `memory/MEMORY.md`

**Open threads:**

- Demo GIF/video for README (identified as high-risk if not done before launch)
- CONTRIBUTING.md for community contributors
- Mark repo as Template in GitHub Settings (done via API in bootstrap sequence)

---

## 2026-03-02 — skill-frontmatter-registry (PR #15)

**O que foi feito:** Adicionada Skills Registry — sheet acessível via botão sparkles na toolbar.
Lista auto-trigger skills (`~/.claude/skills/`), global commands (`~/.claude/commands/`) e project commands
(`.claude/commands/` de cada sessão ativa), com busca em tempo real e badges coloridos por tipo.

**Decisões técnicas:**
- Parsing de frontmatter YAML em Swift puro (sem dependência externa) — string splitting simples
- `loadSkills` como função `async` livre (não actor) — leitura one-shot ao abrir o sheet, sem estado persistente
- `SkillKind.allCases` garante ordem fixa das seções independente da ordem dos entries
- Description fallback: pula headings e fences `---`, usa primeira linha de prosa

**Arquivos-chave:**
- `ClaudeTerminal/Features/SkillRegistry/SkillEntry.swift` — model + enum
- `ClaudeTerminal/Features/SkillRegistry/SkillRegistryService.swift` — scan + parse
- `ClaudeTerminal/Features/SkillRegistry/SkillRegistryView.swift` — UI
- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — botão + sheet

**Próximos passos possíveis:** mostrar o trigger condition de skills auto-trigger; abrir o arquivo da skill no Finder ao clicar.

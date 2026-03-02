# HANDOVER.md — Session history

Newest entries at the top.

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
- `.claude/commands/start-feature.md`, `ship-feature.md`, `close-feature.md`, `handover.md`, `sync-skills.md`
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

**O que foi feito:** Adicionada Skills Registry — sheet acessível via botão sparkles na toolbar do Dashboard. Lista auto-trigger skills (`~/.claude/skills/`), global commands (`~/.claude/commands/`) e project commands (`.claude/commands/` de cada sessão ativa), com busca em tempo real e badges coloridos por tipo.

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

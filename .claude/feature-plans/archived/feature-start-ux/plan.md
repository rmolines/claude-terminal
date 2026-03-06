# Plan: feature-start-ux

## Problema

Dev abre a aba Worktrees, vê a lista de branches mas não tem como criar um novo worktree + iniciar
uma sessão Claude Code sem sair para o terminal. A feature adiciona um botão "+" na aba Worktrees
que: cria o worktree via git, abre o terminal nesse diretório, e opcionalmente injeta
`/start-feature <name>` no PTY.

## Assunções

<!-- status: [assumed] = não verificada | [verified] = confirmada | [invalidated] = refutada -->
<!-- risco:   [blocking] = falsa bloqueia a implementação | [background] = emerge naturalmente -->

- [verified][blocking] `TerminalViewRepresentable` já tem `initialInput: String?` que dispara 1.5s após spawn
- [verified][blocking] `GitStateService.runGit` é `private` mas acessível dentro do próprio actor — `addWorktree` pode chamá-lo diretamente
- [assumed][background] `git worktree add` não requer working tree limpo — apenas `git rebase` requer
- [assumed][background] `makeTerminal(for:)` é chamado durante view building — ler `pendingInitialInput` por closure é seguro; limpar na UI via action explícita

## Questões abertas

**Resolver antes de começar (human gate now):**
- nenhuma — escopo está claro

**A implementação vai responder (monitorar):**
- `git worktree add` com `baseBranch = "main"` falha se o repo só tem `master`? (mitigação: tentar `main`, fallback `master` — igual ao `commitsAhead`)

**Explicitamente fora do escopo:**
- Seleção de baseBranch pelo usuário (sempre usa main/master)
- Deletar worktrees pela UI
- Renomear features

## Deliverables

### Deliverable 1 — Core: git + sheet + botão

**O que faz:** `addWorktree` no `GitStateService`, `NewWorktreeSheet.swift` com validação e toggle,
botão "+" em `WorktreesView` que abre a sheet e navega para o path criado.
`WorktreesView.onSelect` muda para `(String, String) -> Void` (path + initialInput).

**Critério de done:** Build verde. Sheet abre, campo aceita só kebab-case, botão Create chama git e fecha.
WorktreesView notifica ProjectDetailView com o path criado.

**Valida:** assunção sobre `runGit` acessível; assunção sobre `git worktree add`

**⚠️ Execute `/checkpoint` antes de continuar para o Deliverable 2.**

### Deliverable 2 — initialInput wiring no ProjectDetailView

**O que faz:** `ProjectDetailView` aceita `initialInput` em `openPath`, armazena em `pendingInitialInput`,
passa para `makeTerminal`. Restart limpa o `pendingInitialInput` para o path.

**Critério de done:** Build verde. Criar worktree com toggle ativo abre terminal e injeta
`/start-feature <name>` após 1.5s. Restart do terminal NÃO re-injeta.

**Valida:** assunção sobre `initialInput` sendo passado corretamente ao `TerminalViewRepresentable`

## Arquivos a modificar

- `ClaudeTerminal/Services/GitStateService.swift` — novo método `addWorktree(name:in:) async throws -> String`
- `ClaudeTerminal/Features/Worktrees/WorktreesView.swift` — botão "+", `.sheet()`, callback `(String, String) -> Void`
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — `pendingInitialInput` state, `openPath(initialInput:)`, `makeTerminal` lê pending, restart limpa pending
- **Novo:** `ClaudeTerminal/Features/Worktrees/NewWorktreeSheet.swift` — form minimalista

## Passos de execução

1. `GitStateService.swift` — adicionar `addWorktree(name:in:) async throws -> String` [D1]
2. Criar `NewWorktreeSheet.swift` — TextField kebab-case, Toggle "Inject /start-feature", validação inline, Create/Cancel [D1]
3. `WorktreesView.swift` — mudar `onSelect: (String) -> Void` → `(String, String) -> Void`; adicionar `@State private var showSheet = false`; toolbar "+" button; `.sheet(isPresented: $showSheet)`; row tap passa `("", "")` → `(wt.path, "")` [D1]
4. `ProjectDetailView.swift` — atualizar callsite do `WorktreesView` para receber `(String, String)` [D1]
5. ⚠️ Execute `/checkpoint` — Deliverable 1 concluído
6. `ProjectDetailView.swift` — adicionar `@State private var pendingInitialInput: [String: String] = [:]`; `openPath(_ path: String, initialInput: String? = nil)` salva em `pendingInitialInput`; `makeTerminal(for:)` lê `pendingInitialInput[path]`; `restartCurrentTerminal()` limpa `pendingInitialInput[project.displayPath]` [D2]

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

```bash
git checkout HEAD -- ClaudeTerminal/Services/GitStateService.swift
git checkout HEAD -- ClaudeTerminal/Features/Worktrees/WorktreesView.swift
git checkout HEAD -- ClaudeTerminal/Features/Terminal/ProjectDetailView.swift
rm -f ClaudeTerminal/Features/Worktrees/NewWorktreeSheet.swift
```

## Learnings aplicados

- `runGit` é `private` mas métodos no mesmo actor podem chamá-lo — sem necessidade de mudar visibility
- `initialInput` já suportado por `TerminalViewRepresentable` com delay 1.5s — nenhum trabalho extra no PTY layer
- Não usar `NSPanel` para sheet modal de criação — `.sheet()` SwiftUI é o padrão correto
- Validar nome antes de qualquer operação git: regex `^[a-z][a-z0-9-]{0,48}$` (CVE-2025-59536)

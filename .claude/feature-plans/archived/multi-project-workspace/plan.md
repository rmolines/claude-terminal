# Plan: multi-project-workspace

## Problema

Claude Terminal só roda um projeto por vez. Trocar de projeto (`workingDirectory`) mata a
sessão Claude ativa. Devs com múltiplos repos em paralelo não têm como manter N sessões
Claude simultâneas sem N janelas de terminal separadas.

## Decisões

- **Abordagem B**: SwiftData com `ClaudeProject` como fonte de verdade para a lista de projetos
- **Display name**: `basename(git_root)` automático, editável pelo usuário depois
- **`~/.claude.json` resilience**: fora do escopo desta feature
- **Store name distinto**: usar nome diferente do store antigo (`.ClaudeTerminalProjectsV1.store`) para evitar conflito com stores do ciclo DashboardView anterior

## Assunções

<!-- status: [assumed] = não verificada | [verified] = confirmada | [invalidated] = refutada -->
<!-- risco:   [blocking] = falsa bloqueia a implementação | [background] = emerge naturalmente -->
- [verified][blocking] `MainView` usa `@AppStorage("workingDirectory")` + `@AppStorage("recentDirectoriesData")` — esses dados viram `ClaudeProject` entities
- [verified][background] `TerminalViewRepresentable` wrapa `LocalProcessTerminalView` — o processo PTY roda independente de visibilidade da SwiftUI view
- [assumed][blocking] SwiftUI mantém `TerminalViewRepresentable` alive em `ZStack` mesmo quando `opacity(0)` — o processo não é terminado ao trocar de projeto
- [assumed][background] `@preconcurrency import SwiftData` + `var`/`Optional` em relacionamentos é suficiente para Swift 6 strict concurrency
- [assumed][background] Store novo (nome diferente) evita conflito com store residual do ciclo DashboardView

## Questões abertas

**A implementação vai responder (monitorar):**
- SwiftUI preserva `TerminalViewRepresentable` vivo em `ZStack` opacity(0)? Se não, precisamos usar `isHidden` via NSViewRepresentable ou `NSHostingView` por fora.
- Store residual do ciclo DashboardView (`ClaudeTerminal.store`) causa crash no Xcode ao apontar para o novo schema? Monitorar no primeiro build.

**Explicitamente fora do escopo:**
- Resiliência `~/.claude.json` race condition
- Importar sessões históricas do Claude Code
- PR status, task backlog, prioridades (remover esses dados do schema anterior)
- Multi-window (cada projeto em janela separada do macOS)

## Deliverables

### Deliverable 1 — Walking Skeleton: sidebar + 1 terminal

**O que faz:** Substitui `TabView` em `MainView` por `NavigationSplitView` — sidebar esquerda
lista `ClaudeProject` entities do SwiftData, painel direito mostra o terminal do projeto
selecionado. Migra `@AppStorage("workingDirectory")` + `recentDirectoriesData` para
`ClaudeProject` entities on first launch.

**Critério de done:** App abre com sidebar de projetos; clicar num projeto muda o terminal;
"Open Folder…" cria novo `ClaudeProject`; projetos persistem entre relaunches.

**Valida:** SwiftData store inicializa sem crash; `ModelContainer` attachado à `WindowGroup`; migração de `@AppStorage` → entities funciona na primeira abertura.

**Resolve:** fundação de dados e UI.

**Deixa aberto:** apenas 1 terminal ativo — trocar de projeto ainda mata a sessão anterior.

**⚠️ Execute `/checkpoint` antes de continuar para o Deliverable 2.**

---

### Deliverable 2 — Multi-terminal: sessões simultâneas

**O que faz:** Mantém todos os `TerminalViewRepresentable` vivos em `ZStack` (um por projeto
aberto). Trocar de projeto na sidebar troca visibilidade (`opacity(1/0)` ou `isHidden`) sem
matar o processo PTY. Projetos "fechados" (removidos da sidebar) terminam o processo.

**Critério de done:** Iniciar `claude` em Projeto A → trocar para Projeto B → iniciar `claude`
em B → voltar para A → sessão A ainda está rodando com o mesmo contexto (sem restart do PTY).

**Valida:** a assunção crítica de que SwiftUI mantém `TerminalViewRepresentable` alive em ZStack.

**Resolve:** o problema central da feature (múltiplas sessões simultâneas).

**Deixa aberto:** sem contexto visual de status (qual projeto está rodando, tokens, etc.).

**⚠️ Execute `/checkpoint` antes de continuar para o Deliverable 3.**

---

### Deliverable 3 — Project context: status + git root grouping

**O que faz:** Cada row na sidebar mostra status visual do projeto (idle/running/awaiting).
`SessionManager`/`SessionStore` detecta git root do `cwd` e associa à `ClaudeProject`
correspondente. Worktrees do mesmo repo aparecem agrupadas sob o mesmo projeto (ou como
sub-items do projeto pai).

**Critério de done:** Iniciar Claude em worktree → projeto correspondente na sidebar mostra
badge "running"; permissão HITL pendente mostra badge diferente. Abrir 2 worktrees do mesmo
repo → aparecem sob o mesmo projeto.

**Valida:** bridge `SessionManager` (actor) → `SessionStore` (@MainActor) → `ClaudeProject` upsert via SwiftData.

## Arquivos a modificar

**Deliverable 1 — SwiftData Foundation:**
- `ClaudeTerminal/Models/ClaudeProject.swift` — criar `@Model` (id, name, path=git_root, displayPath=cwd, createdAt, sortOrder, isActive)
- `ClaudeTerminal/Models/AppMigrationPlan.swift` — criar (schema v1 com ClaudeProject only, store name distinto)
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — adicionar `ModelContainer`, `.modelContainer(sharedContainer)`
- `ClaudeTerminal/Features/Terminal/MainView.swift` — substituir `TabView` por `NavigationSplitView`; migrar `@AppStorage` → SwiftData na primeira abertura

**Deliverable 2 — Multi-terminal:**
- `ClaudeTerminal/Features/Terminal/MainView.swift` — `ZStack` de `TerminalViewRepresentable` (um por projeto aberto), visibilidade controlada por projeto selecionado

**Deliverable 3 — Status + Git Root:**
- `ClaudeTerminal/Services/GitStateService.swift` — adicionar `func gitRootPath(for cwd: String) async -> String?`
- `ClaudeTerminal/Services/SessionStore.swift` — ao receber `AgentSession`, detectar git root e upsert `ClaudeProject` via `ModelContext`
- `ClaudeTerminal/Features/Terminal/MainView.swift` (sidebar row) — badge de status baseado em `SessionStore`

## Passos de execução

### Deliverable 1

1. Criar `ClaudeTerminal/Models/ClaudeProject.swift` — `@Model final class ClaudeProject` com id, name, path, createdAt, sortOrder
2. Criar `ClaudeTerminal/Models/AppMigrationPlan.swift` — `ModelConfiguration(url: storeURL)` com nome distinto; sem migration stages (store novo)
3. Editar `ClaudeTerminalApp.swift` — criar `ModelContainer`, adicionar `.modelContainer()` à `WindowGroup`
4. Editar `MainView.swift` — `@Query var projects: [ClaudeProject]`; `NavigationSplitView` sidebar + detail; migrar `@AppStorage("recentDirectoriesData")` → `ClaudeProject` entities no `.onAppear` (one-shot, guarded by `projects.isEmpty`)
5. Build via Xcode MCP `BuildProject` — verificar zero erros
6. ⚠️ Execute `/checkpoint` — Deliverable 1 concluído

### Deliverable 2

7. Editar `MainView.swift` — adicionar `@State private var openProjects: [PersistentIdentifier: UUID]` (mapeia projeto → sessionID do PTY)
8. Em vez de trocar `workingDirectory`, adicionar ao `openProjects` e usar `ZStack { ForEach(openProjects) { ... TerminalViewRepresentable(...).opacity(isSelected ? 1 : 0) } }`
9. "Fechar" projeto = remover de `openProjects` (PTY termina)
10. Build + teste manual (abrir 2 projetos, verificar que ambos persistem)
11. ⚠️ Execute `/checkpoint` — Deliverable 2 concluído

### Deliverable 3

12. Adicionar `gitRootPath(for:)` em `GitStateService.swift`
13. Em `SessionStore.update(_ session: AgentSession)` — chamar `gitRootPath`, fazer upsert de `ClaudeProject` no `@MainActor ModelContext`
14. Adicionar `status: String` em `ClaudeProject` (idle/running/awaiting) — atualizado pelo SessionStore
15. Sidebar row — ler `project.status` e exibir badge
16. Build final

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Novas dependências: não (SwiftData built-in)

## Rollback

```bash
git checkout main  # descarta worktree inteiro
```

## Learnings aplicados

- **SwiftData entity name mismatch** (MEMORY.md): inner classes em SchemaVN devem ter o MESMO nome — aqui não há schema migration, mas store name distinto evita conflito.
- **`@preconcurrency import SwiftData`** (MEMORY.md): em `AppMigrationPlan.swift`.
- **`var` e Optional em relacionamentos** (MEMORY.md): `ClaudeProject` não tem relacionamentos neste ciclo — simples.
- **Actor + blocking I/O** (MEMORY.md): `gitRootPath` usa `Process` — chamar de `nonisolated` ou `@MainActor`, não de método isolado de actor.
- **Store residual DashboardView**: usar `ModelConfiguration(url:)` com store name diferente do default para não conflitar.

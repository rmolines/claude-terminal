# Research: feature-start-ux

## Descrição da feature

Adicionar botão "+" na aba Worktrees que:
1. Abre uma sheet SwiftUI com 1 campo de texto (nome da feature, kebab-case)
2. Cria git worktree via `GitStateService` (novo método `addWorktree`)
3. Abre o terminal no novo diretório (via `ProjectDetailView.openPath`)
4. Opcionalmente injeta `/start-feature <name>` no spawn do PTY via `initialInput`

Constraint C2 (read-only terminals): injection só funciona no momento de spawn — já suportado
pela arquitetura existente de `TerminalViewRepresentable.initialInput`.

## Arquivos existentes relevantes

- `ClaudeTerminal/Features/Worktrees/WorktreesView.swift` — view principal da aba Worktrees; aqui vai o botão "+" e a sheet
- `ClaudeTerminal/Services/GitStateService.swift` — actor de git; tem `runGit(args:cwd:)` como template; **não tem** `addWorktree()` ainda
- `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift` — wrapper do PTY; tem `initialInput: String?` que envia comando 1.5s após spawn via `tv.send(data:)`
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — faz o spawn do PTY via `makeTerminal(for:)`; `openPath(_:)` cria sessão synthetic e trigga spawn
- `ClaudeTerminal/Services/SessionStore.swift` — `@Observable`; fonte de verdade das sessões ativas para a UI
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — referência de NSPanel (não é o padrão para esta feature — usar `.sheet()`)

## Padrões identificados

**Criação do worktree (novo):**
Usar `GitStateService.runGit(args:cwd:)` como template para novo método `addWorktree(name:baseBranch:in:)`.
O método executa `git worktree add .claude/worktrees/<name> -b feature/<name> <baseBranch>`.
`runGit` já usa `Process` com `terminationHandler` + continuation — copiar o padrão.

**Abertura do PTY após criar worktree:**
`ProjectDetailView.openPath(newPath)` já existe e cria sessão synthetic que trigga `makeTerminal`.
Após `addWorktree()`, chamar o equivalente de `openPath` com o novo path.
O `initialInput` precisa ser passado no momento da criação do `TerminalViewRepresentable`.

**UI sheet:**
Usar SwiftUI `.sheet()` nativo — formulário modal com 1 campo é o caso canônico.
NSPanel seria overkill aqui (é para floating HUD não-modal, não para criação modal).

**Focus automático no TextField:**
```swift
@FocusState private var focused: Bool
TextField("nome-da-feature", text: $featureName)
    .focused($focused)
    .defaultFocus($focused, true)  // macOS 15
// fallback macOS 14: .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { focused = true } }
```

**Validação do nome:**
Apenas `[a-z0-9-]`, 1–50 chars, kebab-case. Validar antes de construir qualquer argumento git.
Necessário para prevenir injeção via nome malicioso (CVE-2025-59536).

**`git worktree add` em Swift 6:**
`Process.waitUntilExit()` é bloqueante — NUNCA em `@MainActor`.
`GitStateService` já é um `actor` — método `nonisolated` + `async` com `withCheckedThrowingContinuation`
(mesmo padrão do `runGit` existente).

## Dependências externas

Nenhuma — todo o necessário já existe no projeto.

## Hot files que serão tocados

- `ClaudeTerminal/Services/GitStateService.swift` — novo método `addWorktree(name:baseBranch:in:) async throws`
- `ClaudeTerminal/Features/Worktrees/WorktreesView.swift` — botão "+" na toolbar + `.sheet()` + call a `GitStateService`
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — expor/ajustar rota para abrir novo worktree com `initialInput` opcional
- **Novo arquivo:** `ClaudeTerminal/Features/Worktrees/NewWorktreeSheet.swift` — form minimalista

`SessionManager.swift` e `TerminalRegistry.swift` têm mudanças uncommitted em `main`
(dos worktrees `session-restore-install` e `ship-close-skill-overhead`). Esta feature
não toca esses arquivos, mas é necessário fazer `git stash` antes de criar o worktree.

## Riscos e restrições

| Risco | Mitigação |
|---|---|
| `addWorktree()` chamado em contexto errado -> deadlock | Usar `nonisolated` + `async` com continuation (padrão do `runGit`) |
| Nome com chars especiais -> injeção de comando | Validar regex `^[a-z][a-z0-9-]{0,48}$` antes de qualquer operação git |
| Worktree com mesmo nome ja existe | Checar `GitStateService.worktrees()` antes de `addWorktree`; mostrar erro inline no sheet |
| `initialInput` enviado antes do claude inicializar | 1.5s delay ja implementado; testar com 2s se flaky |
| main com mudanças uncommitted bloqueia `git rebase` | `git stash` antes de criar worktree |
| `initialInput` nao chega ao `TerminalViewRepresentable` | Verificar se `makeTerminal(for:)` aceita o param; pode precisar de ajuste pontual em `ProjectDetailView` |

## Fontes consultadas

- Codebase: leitura direta de `TerminalViewRepresentable.swift`, `GitStateService.swift`, `WorktreesView.swift`, `ProjectDetailView.swift`
- [The SwiftUI cookbook for focus - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10162/)
- [SwiftTerm README - migueldeicaza/SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)
- [NSPanel - Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nspanel)

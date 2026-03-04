# Research: skills-navigator

## Descrição da feature

Uma nova aba "Skills" no Claude Terminal que mostra o estado atual do workflow de skills
por agente, segregada por agente/branch. Cada seção mostra: branch/worktree, fase do workflow,
próximos passos válidos (com comando copiável) e skills disponíveis na fase atual com flags inline.
Launcher contextual — não referência estática.

## Arquivos existentes relevantes

- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — entry point, WindowGroup → MainView (simples)
- `ClaudeTerminal/Features/Terminal/MainView.swift` — VStack: header + TerminalViewRepresentable. **Será modificado para TabView**
- `ClaudeTerminal/Services/SessionStore.swift` — @MainActor @Observable, `sessions: [String: AgentSession]`
- `ClaudeTerminal/Services/SessionManager.swift` — actor central; `AgentSession` struct tem `cwd`, `status`, `currentActivity`, `recentMessages`
- `ClaudeTerminal/Services/HookIPCServer.swift` — NÃO tocado; Skills Navigator é só leitura de estado
- `Shared/IPCProtocol.swift` — NÃO tocado; nenhuma mudança de protocolo necessária

## Padrões identificados

- **@Observable pattern:** SessionStore.shared é acessado diretamente nas views (sem @StateObject). SessionManager→SessionStore via `Task { @MainActor in SessionStore.shared.update(session) }`
- **Processo async:** usar `Foundation.Process` com `withCheckedThrowingContinuation` (nonisolated) — não `swift-subprocess` (ainda experimental/preview)
- **TabView macOS:** `TabView` sem modificador especial renderiza tabs horizontais — adequado para 2 tabs. `sidebarAdaptable` tem bugs no macOS 15.1; evitar.
- **Polling via `.task {}`:** cancela automaticamente quando a view desaparece; ideal para polling periódico de estado externo
- **NSPasteboard para copy:** `NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cmd, forType: .string)`
- **Toolbar no detalhe, não no container:** `.toolbar {}` nas subviews, nunca no TabView direto (bug macOS 14/15)

## Estrutura de dados

`AgentSession` (já existe em SessionManager.swift):
```swift
struct AgentSession: Sendable {
    let sessionID: String
    let cwd: String            // usado para derivar branch/worktree
    var status: AgentStatus    // running, awaitingInput, completed, blocked
    var currentActivity: String?
    var subAgentCount: Int
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var totalCacheReadTokens: Int
    var recentMessages: [String]
}
```

`cwd` é o campo-chave: se contém `.claude/worktrees/`, agente está em feature ativa.
Branch derivada via `git branch --show-current` executado no cwd.

## Dependências externas

- Nenhuma nova dependência SPM — `Foundation.Process` para git queries
- `/usr/bin/git` (disponível em qualquer macOS)

## Hot files que serão tocados

- `ClaudeTerminal/Features/Terminal/MainView.swift` — adicionar TabView ⚠️ (arquivo existente, mudança estrutural)
- Novos arquivos em `ClaudeTerminal/Features/Skills/` (sem conflito)
- Novo arquivo `ClaudeTerminal/Services/GitStateService.swift` (sem conflito)

## Riscos e restrições

| Risco | Mitigação |
|---|---|
| `git branch --show-current` pode ser lento em repos grandes | Timeout de 3s no Process; fallback para `cwd` string parsing |
| cwd pode ser inválido se sessão foi iniciada em pasta deletada | `try?` — falha silenciosa, mostrar "—" em vez de branch |
| SessionStore pode estar vazio (sem agentes) | Empty state view com instrução "Start Claude Code…" |
| TabView no macOS pode ter aparência diferente do esperado | `tabItem` funciona bem; testar antes de ship |
| WorkflowPhase inference baseada em branch name pode errar | Apresentar como "sugestão" — não assertivo. Usuário sabe o estado real. |

## Fontes consultadas

- Subagente A: análise completa do codebase (commit 798d9df "terminal-first UI")
- Subagente B: análise de conflitos — seguro prosseguir
- Subagente C: padrões SwiftUI macOS 2025-2026
  - NavigationSplitView: https://swiftwithmajid.com/2022/10/18/mastering-navigationsplitview-in-swiftui/
  - Foundation.Process async: https://troz.net/post/2025/process-subprocess/
  - swift-subprocess status: https://swiftpackageindex.com/swiftlang/swift-subprocess
  - Task polling: https://fatbobman.com/en/posts/mastering_swiftui_task_modifier/

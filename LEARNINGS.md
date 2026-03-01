# LEARNINGS.md — Technical learnings

Gotchas, limitations, and non-obvious behaviors discovered while working on this project.

---

## 2026-03-01 — task-backlog-persistence: `ModelContainer` fica na cena App, não na view raiz

O `ModelContainer` deve ser configurado uma única vez na `Scene` (via `.modelContainer(for:)` na `WindowGroup`),
não na view raiz nem em views filhas. Isso injeta `ModelContext` em toda a hierarquia.

```swift
// CERTO — na Scene (ClaudeTerminalApp.swift)
WindowGroup("...") { RootView() }
    .modelContainer(for: [ClaudeTask.self, ClaudeAgent.self])

// ERRADO — na view raiz ou filha
struct RootView: View {
    let container = try! ModelContainer(for: ClaudeTask.self) // não compartilhado
}
```

**Por quê importa:** múltiplos containers criam múltiplos `ModelContext`s isolados — mutations em um
não aparecem em queries do outro. Definindo na `Scene`, todas as views compartilham o mesmo container.

---

## 2026-03-01 — task-backlog-persistence: `sortOrder` manual é obrigatório em toda lista SwiftData

SwiftData não preserva a ordem de inserção de arrays ao recarregar do disco. Sem um `sortOrder` explícito,
a lista reordena aleatoriamente a cada restart.

```swift
// SEMPRE passar sort para @Query
@Query(sort: \ClaudeTask.sortOrder) private var tasks: [ClaudeTask]

// SEMPRE calcular sortOrder antes de inserir
let nextOrder = (tasks.map(\.sortOrder).max() ?? -1) + 1
task.sortOrder = nextOrder
```

Já documentado em CLAUDE.md como armadilha — confirma que o padrão é necessário.

---

## 2026-03-01 — task-backlog-persistence: `context.save()` explícito após toda mutation

SwiftData tem auto-save não confiável. Após `context.insert()` ou `context.delete()`, sempre chamar
`try? context.save()` para garantir persistência imediata. Omitir pode resultar em dados perdidos se
o app crasha antes do próximo ciclo de auto-save.

---

## 2026-03-01 — `git pull --rebase origin main` é necessário após squash merge em worktree workflow

Após um squash merge via `gh pr merge --squash`, o commit local do `main` que foi feito durante o
período do PR (ex: docs, outros merges) diverge do squash commit no remote. `git pull` sem `--rebase`
falha porque os branches divergem.

**Solução:** sempre usar `git pull --rebase origin main` no fechamento de features para reconciliar
sem criar merge commits desnecessários.

---

## 2026-03-01 — dashboard-tokens: `@ViewBuilder` com `if` é mais limpo que `AnyView`

Para views condicionais em SwiftUI, `@ViewBuilder` com `if` simples é idiomático e elimina o boxing de `AnyView`:

```swift
// ERRADO — boxing desnecessário
private var tokenBadge: some View {
    guard total > 0 else { return AnyView(EmptyView()) }
    return AnyView(Text("..."))
}

// CERTO — @ViewBuilder infere o tipo condicional
@ViewBuilder
private var tokenBadge: some View {
    if total > 0 {
        Text("...")
    }
}
```

`AnyView` apaga o tipo e prejudica a diff tree do SwiftUI. Preferir sempre `@ViewBuilder` + `if`.

---

## 2026-03-01 — dashboard-tokens: actor mirror em testes precisa de `SessionState` struct quando acumula estado

Quando o `LocalSessionManager` mirror nos testes precisa rastrear mais do que status (ex: contadores
de tokens), modelar com uma `struct SessionState` interna é mais legível do que múltiplos
dicionários paralelos:

```swift
// EVITAR — dicionários paralelos por campo
private var statuses: [String: AgentStatus] = [:]
private var inputTokens: [String: Int] = [:]

// PREFERIR — struct interna
private struct SessionState {
    var status: AgentStatus = .running
    var totalInputTokens: Int = 0
    ...
}
private var sessions: [String: SessionState] = [:]
```

---

## 2026-03-01 — `gh pr merge --delete-branch` falha em worktrees

`gh pr merge --squash --delete-branch` tenta fazer `git checkout main` localmente para deletar o branch.
Em worktrees, `main` já está checked out no repo pai — o comando falha com:
`fatal: 'main' is already checked out at '...'`

**Solução:** usar `gh pr merge --squash` (sem `--delete-branch`) e deletar o remote branch separadamente via API:
```bash
gh api -X DELETE repos/<owner>/<repo>/git/refs/heads/<branch>
```

---

## 2026-03-01 — Targets executáveis SPM não suportam `@testable import`

SPM não permite `@testable import` de targets do tipo `.executableTarget`.
Qualquer lógica que precise ser testada diretamente deve viver em um `.target` (library).

**Solução adotada:** criar um actor mirror local no arquivo de testes que reimplementa a state machine
usando apenas tipos do módulo `Shared` (que é uma library). Documentar no comentário do test file
o motivo do padrão.

**Solução ideal a longo prazo:** extrair `SessionManager`, `SessionStore` e `HookIPCServer` para um
target `ClaudeTerminalCore` do tipo `.target`, e o executável depende desse target.

---

## GitHub Actions

### `bootstrap.yml`: `run_number == 1` guard

`github.run_number` starts at 1 for the first run of any workflow in a repo. Using this as a
guard ensures branch protection is only applied once. **Do not re-run this workflow manually** —
it will attempt to apply protection again (which is usually fine but clutters logs).

### `template-sync.yml`: must guard with `!is_template`

Without the `!github.event.repository.is_template` guard, the sync workflow would run on the
template repo itself and open PRs against its own `main`. The guard makes it a no-op on the
template and active only on forks.

### Action SHA pinning

Always pin to full commit SHA, not tag:
```yaml
# Good
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
# Bad (tag can be hijacked)
uses: actions/checkout@v4
```

---

## 2026-03-01 — Actor deadlock com blocking C calls (accept/read)

Chamadas C bloqueantes (`accept()`, `read()`, `recv()`) dentro de métodos de ator Swift seguram
o ator indefinidamente. Qualquer outro método do mesmo ator que seja chamado enquanto isso
fica enfileirado esperando — nunca executa. Isso inclui métodos chamados via `Task.detached`.

**Sintoma:** eventos chegam no socket (conexão aceita pelo kernel), mas `handleConnection`
nunca roda. Nenhum print, nenhum erro, silêncio total.

**Causa raiz:** `runServer()` era um método do ator com `while { accept(...) }` bloqueante.
`handleConnection()` era outro método do mesmo ator — nunca conseguia adquirir o ator.

**Solução:** mover todo I/O bloqueante para funções `nonisolated` rodando em `Thread`s
dedicadas (não em `Task` do Swift Concurrency — `Task.detached` usa o cooperative pool que
também não deve bloquear). O ator fica responsável apenas por mutações de estado, acessadas
nas bordas via `Task { await ... }`.

```swift
// ERRADO — bloqueia o ator
private func runServer() async {
    while isRunning { let fd = accept(...) ... }  // deadlock
}

// CERTO — I/O bloqueante fora do ator
nonisolated private func acceptLoop(...) {
    while true { let fd = accept(...) ... }       // Thread, não ator
}
func start() {
    let t = Thread { self.acceptLoop(...) }       // Thread dedicada
    t.start()
}
```

**Regra geral:** nunca chamar `accept()`, `read()`, `recv()`, `sem_wait()` ou qualquer
syscall bloqueante de dentro de um método de ator. Usar `Thread` dedicada + `nonisolated`.

---

## 2026-03-01 — `TimelineView` é a forma correta de timers live no SwiftUI

Para tickers que precisam atualizar a cada segundo (ex: elapsed time), usar `TimelineView(.periodic(from: .now, by: 1.0))`.
Alternativas como `Timer.publish` ou `onAppear + Task { while true { sleep } }` são mais frágeis e não se integram bem com o ciclo de vida do SwiftUI.

`TimelineView` re-renderiza apenas a view interna — não invalida views pai — então é seguro usá-lo em cada row de uma lista sem degradar performance.

---

## 2026-03-01 — Propagar `detail` por toda a pipeline IPC sem breaking change

Adicionar um campo `optional` com default `nil` em `AgentEvent` (Codable) é totalmente backward-compatible:
decoders antigos ignoram o campo, encoders antigos omitem-no. Isso permite introduzir contexto extra
(ex: bash command, permission description) sem versionar o protocolo.

**Padrão:** sempre usar `optional` + `default = nil` para campos novos em structs `Codable` de IPC.

---

## Claude Code hooks (CVE-2025-59536)

Hooks in `.claude/settings.json` execute shell commands **without user confirmation**.
This was documented in CVE-2025-59536. Mitigation: keep hook logic in external scripts
(`.claude/hooks/`) so they're visible, auditable, and can be reviewed in PRs.

---

## 2026-03-01 — terminal-per-agent-ui: `.id(sessionID)` força recriação de PTY no SwiftUI

`TerminalViewRepresentable` é um `NSViewRepresentable` — SwiftUI reutiliza a NSView quando a
view é "a mesma" na árvore. Para forçar a destruição e recriação do PTY ao trocar de sessão,
usar `.id(session.sessionID)` na view: SwiftUI trata views com IDs diferentes como instâncias
distintas e cria uma nova.

```swift
TerminalViewRepresentable(...)
    .id(session.sessionID)  // novo sessionID → novo PTY
```

Sem isso, trocar de sessão reutiliza o shell da sessão anterior no processo existente.

---

## 2026-03-01 — terminal-per-agent-ui: cwd via `cd && exec` em args, não `workingDirectory:`

`LocalProcessTerminalView.startProcess` não expõe um parâmetro `workingDirectory:`. Para
iniciar o shell no diretório correto, passar via args com single-quote escaping:

```swift
let escaped = cwd.replacingOccurrences(of: "'", with: "'\\''")
args: ["-c", "cd '\(escaped)' && exec zsh"]
```

O `exec zsh` substitui o processo de shell intermediário (`-c`) pelo shell interativo
final — o processo filho fica limpo, sem um processo pai `-c` residual.

---

## 2026-03-01 — terminal-per-agent-ui: env allowlist para processos filhos

Ao spawnar processos via `startProcess(environment:)`, nunca passar o ambiente do processo
pai inteiro — pode conter tokens, variáveis de sessão, credenciais. Usar allowlist mínima:

```swift
environment: [
    "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin",
    "HOME=\(NSHomeDirectory())",
    "TERM=xterm-256color"
]
```

Homebrew no macOS arm64 fica em `/opt/homebrew/bin` — incluir explicitamente para que
ferramentas como `git`, `gh`, `brew` funcionem no terminal embedado.

---

## 2026-03-01 — terminal-per-agent-ui: 3-column `NavigationSplitView` é idiomático para master-detail-detail

Para layouts com sidebar + lista de seleção + painel de detalhe, o 3-column `NavigationSplitView`
é a API correta no macOS/SwiftUI:

```swift
NavigationSplitView {
    // sidebar
} content: {
    List(items, id: \.id, selection: $selectedID) { ... }
} detail: {
    if let item = selected { DetailView(item) } else { EmptyState() }
}
```

macOS gerencia o colapso/expansão das colunas laterais nativamente — sem código extra.
O `List` com `selection:` binding atualiza `selectedID` automaticamente ao clicar numa row.

---

## 2026-03-01 — agent-spawn-ui: segundo `WindowGroup` precisa de `.modelContainer` próprio

Ao adicionar um segundo `WindowGroup` (para janelas de agente) no `App`, SwiftData **não** herda
o container da scene principal — cada `WindowGroup` precisa da sua própria chamada `.modelContainer(for:)`:

```swift
WindowGroup("Agent", id: "agent-terminal", for: AgentTerminalConfig.self) { $config in
    SpawnedAgentView(config: config!)
}
.modelContainer(for: [ClaudeTask.self, ClaudeAgent.self])  // obrigatório
```

Sem isso, views dentro do segundo `WindowGroup` não recebem `ModelContext` via `@Environment`
e queries com `@Query` ficam vazias silenciosamente.

---

## 2026-03-01 — agent-spawn-ui: `openWindow(id:value:)` para tipagem segura na API de janelas

Para abrir uma janela com dados, usar `openWindow(id:value:)` onde `value` é um tipo `Codable & Hashable`.
SwiftUI serializa o valor e o entrega ao `WindowGroup` via o binding `$config`:

```swift
// Em qualquer view com @Environment(\.openWindow):
openWindow(id: "agent-terminal", value: AgentTerminalConfig(...))

// No App:
WindowGroup("Agent", id: "agent-terminal", for: AgentTerminalConfig.self) { $config in
    if let c = config { SpawnedAgentView(config: c) }
}
```

Esse padrão funciona para qualquer dado que precise ser passado a uma janela — alternativa
type-safe ao `NSWindowController` manual ou `NotificationCenter`.

---

## 2026-03-01 — agent-spawn-ui: `NSOpenPanel` em SwiftUI via chamada síncrona em `@MainActor`

`NSOpenPanel.runModal()` é síncrono e deve rodar na main thread. Em SwiftUI, como views já rodam
em `@MainActor`, basta chamar diretamente — sem `Task` ou `await`:

```swift
private func browseForRepo() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    if panel.runModal() == .OK, let url = panel.url {
        repoPath = url.path
    }
}
```

Não envolver em `Task { ... }` — `NSOpenPanel.runModal()` bloqueia o run loop corretamente
e retorna quando o usuário fecha o painel.

---

## 2026-03-01 — agent-spawn-ui: `zsh -c "cd '...' && claude"` para iniciar agent no worktree

Para spawnar `claude` em um diretório específico via `TerminalViewRepresentable`, usar
o mesmo padrão de `cd` via args que já foi documentado, mas com `claude` em vez de `exec zsh`:

```swift
let escaped = worktreePath.replacingOccurrences(of: "'", with: "'\\''")
args: ["-c", "cd '\(escaped)' && claude"]
```

Não usar `exec claude` — o `exec` substitui o processo, mas Claude Code pode abrir sub-processos
que precisam do `zsh` pai. Deixar o `zsh -c` wrapping intacto.

---

## markdownlint

- Use `npx --yes markdownlint-cli2` to avoid requiring global install
- `MD013` (line length) needs `tables: false` and `code_blocks: false` to avoid false positives
- `MD024` (duplicate headings) should be disabled for `HANDOVER.md` — entries often have similar structure
- `MD041` (first heading must be h1) breaks templates with frontmatter or `<!-- TODO -->` comments

# LEARNINGS.md — Technical learnings

Gotchas, limitations, and non-obvious behaviors discovered while working on this project.

## 2026-03-07 — `\r` no message-input vs HITL PTY bridge

No HITL PTY bridge, enviar `[0x31, 0x0d]` causava bleeding do `\r` para o próximo dialog
porque o agente estava em **raw mode** (processa byte a byte, sem aguardar terminador de linha).
No message-input, `\r` é necessário: o agente está em **modo normal** e só processa a linha
ao receber `\n`/`\r`. Enviar apenas os bytes UTF-8 sem `\r` faria a mensagem ficar no buffer
sem ser processada.

Regra: usar `+ [0x0d]` ao injetar input de usuário em modo normal; omitir ao responder
dialogs TUI em raw mode.

## 2026-03-06 — Service launch init pattern: `start()` vs `updateRoot()`

Services `@MainActor @Observable` que precisam iniciar no launch (AppDelegate) mas dependem de contexto do usuário (ex: path do projeto) devem separar essas duas responsabilidades:

- `start()` — chamado em `applicationDidFinishLaunching`, inicializa apenas o timer/loop sem contexto
- `updateRoot(_ path: String)` — chamado em `View.onAppear` e `onChange(of:)`, define o contexto e dispara o primeiro poll

Padrão oposto (passar rootDirectory em `start()`) força o AppDelegate a conhecer paths de projeto — acoplamento errado.
Com a separação, o AppDelegate só inicia o serviço; a View é responsável por prover o contexto quando o usuário seleciona um projeto.

## 2026-03-06 — `gh pr create` dentro de worktree retorna "Head sha can't be blank"

`gh pr create` sem flags adicionais falha com `Head sha can't be blank, No commits between main and <branch>`
quando executado de dentro de uma worktree — o CLI não resolve o repositório correto a partir do path da worktree.

**Fix:** usar `--repo owner/repo` explicitamente:

```bash
gh pr create --repo rmolines/claude-terminal --head <branch> --base main --title "..." --body "..."
```

---

## 2026-03-06 — `WindowGroup` + macOS state restoration abre múltiplas janelas no launch

`WindowGroup` no SwiftUI macOS salva e restaura todas as janelas abertas na última sessão.
Em apps single-window, isso faz o app abrir 2-3 janelas após desenvolvimento iterativo no Xcode.

**Fix:** fechar extras em `applicationDidFinishLaunching` via `DispatchQueue.main.async`:

```swift
DispatchQueue.main.async {
    let mainWindows = NSApp.windows.filter { !($0 is NSPanel) }
    mainWindows.dropFirst().forEach { $0.close() }
}
```

Alternativa mais robusta a longo prazo: migrar de `WindowGroup` para `Window` (macOS 13+).

---

## 2026-03-06 — Dashboard sobre ZStack: nunca substituir o ZStack de PTYs com if/else

Mostrar uma view de dashboard via `if showDashboard { Dashboard() } else { ZStack { terminals } }`
destrói todos os PTYs quando o dashboard é exibido — SwiftUI remove o ZStack do tree.

**Fix:** manter o ZStack de terminais sempre presente; sobrepor o dashboard via outer ZStack:

```swift
ZStack {
    ZStack { /* terminais com opacity/allowsHitTesting */ }
    if showDashboard { DashboardView() }
}
```

Os PTYs sobrevivem ao toggle e retomam exatamente onde pararam.

---

## 2026-03-05 — Actor que muta estado local não reflete no @Observable automaticamente

`SessionManager` (actor) e `SessionStore` (@Observable, @MainActor) são stores separados.
Mutar `sessions[id]` dentro do actor **não** notifica o `SessionStore` — é preciso chamar
`Task { @MainActor in SessionStore.shared.update(session) }` explicitamente.
Sem isso, views que observam `SessionStore` nunca recebem o update e parecem "congeladas".
Padrão a seguir: toda mutação de estado que precisa refletir na UI deve terminar com o update explícito ao Store.

---

## 2026-03-05 — `NSHostingView.rootView` durante layout cycle causa EXC_BREAKPOINT no macOS 26

Atualizar `hosting.rootView` enquanto um `NSPanel` está visível invalida constraints do
`NSHostingView(.minSize)` via `setNeedsUpdateConstraints()`. No macOS 26, se essa invalidação
ocorre dentro de um layout cycle em andamento (`postWindowNeedsUpdateConstraints`), o AppKit
lança `NSException` → `EXC_BREAKPOINT (SIGTRAP)`.

**Sintoma:** crash após ~1h de uso, reproduzível apenas quando um painel HITL está visível
enquanto outros eventos de hook chegam (heartbeats, bash commands de outras sessões).
O stack trace aponta para `postWindowNeedsUpdateConstraints + 1716` com `NSException` acima.

**Causa raiz:** observer pattern que atualiza `rootView` em cada mudança de `sessions` —
mesmo quando o conteúdo exibido não muda. A atualização redundante é inofensiva no macOS
14/15, mas problemática no macOS 26.

**Fix:** cachear o conteúdo atual (`currentSessionID` + `currentDescription`). Pular a
atualização de `rootView` se o painel já está visível com o mesmo conteúdo. Limpar cache no dismiss.

```swift
if panel.isVisible,
   session.sessionID == currentSessionID,
   description == currentDescription {
    return  // sem rootView update desnecessário
}
```

---

## 2026-03-05 — `git rev-parse --git-common-dir` para unificar worktrees sob um projeto

`--show-toplevel` retorna o diretório da worktree ativa (ex: `.claude/worktrees/my-feature`) —
cada worktree apareceria como projeto separado. `--git-common-dir` retorna o `.git` compartilhado
do repo principal; seu parent é o canonical root, igual para todas as worktrees.

```swift
let raw = try await runGit(args: ["rev-parse", "--git-common-dir"], cwd: dir)
let absolute = raw.hasPrefix("/") ? raw : (dir as NSString).appendingPathComponent(raw)
return (absolute as NSString).deletingLastPathComponent  // canonical repo root
```

---

## 2026-03-05 — `ModelContainer` não cria diretórios intermediários (SwiftData)

Se o diretório pai do store não existir, `ModelContainer(for:configurations:)` **não falha** —
silenciosamente cria um store in-memory. Dados persistem enquanto o app roda, mas são perdidos
no próximo launch sem aviso.

**Fix obrigatório antes de criar `ModelConfiguration(url:)`:**

```swift
try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
```

---

## 2026-03-04 — `.markdownlint-cli2.yaml` sem `config:` quebra cascade no CI (v0.6.0)

Criar `.markdownlint-cli2.yaml` no repo com apenas `ignores:` (sem `config:`) muda o
comportamento do `markdownlint-cli2-action` v9 com markdownlint v0.27.0: o arquivo
`.markdownlint.yaml` deixa de ser carregado automaticamente, e o linter usa regras default.

**Sintoma:** CI que passava antes (sem `.markdownlint-cli2.yaml`) passa a falhar com
MD049 (emphasis style inconsistente) e MD036 (bold usado como heading) em arquivos que não
foram modificados na PR. A versão local mais recente (v0.21.0) não reproduz o erro porque
o comportamento de cascade mudou entre versões.

**Fix:** sempre incluir `config: .markdownlint.yaml` em `.markdownlint-cli2.yaml`:

```yaml
config: .markdownlint.yaml
ignores:
  - ".build/**"
  - ".swiftpm/**"
```

**Regra:** toda instância de `.markdownlint-cli2.yaml` precisa de `config:` explícito
para garantir comportamento idêntico entre versões do CLI e ambientes CI/local.

---

## 2026-03-04 — Working tree pode ter mais conteúdo do que HEAD após stash pop de worktree cruzado

Quando um `git stash` foi feito dentro de uma worktree com mudanças não commitadas, e depois
`git stash pop` é rodado em outra worktree (ou no main), os arquivos restaurados ficam no
working tree mas NÃO no commit — `git diff HEAD` mostra diferença, mas `git status` apenas
lista `M` (modified, unstaged).

**Caso concreto desta sessão:** `design-review.md` tinha 399 linhas no commit `3c6fab5` mas
541 no working tree após o stash pop (o modo `--audit`, 142 linhas, estava só no stash).
O CI rodou contra o commit (399 linhas, sem erros visíveis), mas as linhas problemáticas
estavam na versão do working tree que foi comitada *depois* do rebase. As duas versões
coexistiram silenciosamente por horas antes de serem reconciliadas.

**Fix:** sempre rodar `git diff HEAD --stat` antes de `git add` para garantir que o
conteúdo staged é exatamente o esperado. Nunca assumir que `git status` mostra o whole diff.

---

## 2026-03-03 — NSPanel `hidesOnDeactivate = false` é obrigatório para floating panels

Por padrão, `NSPanel.hidesOnDeactivate` é `true` — o panel desaparece automaticamente
quando o app perde o foco. Para um panel utilitário que precisa ficar visível enquanto o
usuário trabalha em outro app (ex: HITL approval), isso é o comportamento errado.

**Fix:** `panel.hidesOnDeactivate = false` — panel permanece visível independentemente de qual
app está em foreground. Combinado com `level = .floating`, garante z-order e persistência.

**Armadilha correlata:** `collectionBehavior` precisa incluir `.fullScreenAuxiliary` para o panel
aparecer em cima de apps em full-screen (ex: Xcode em modo full-screen).

---

## 2026-03-02 — Claude Code MCP servers ficam em `~/.claude.json`, não em `settings.json`

`~/.claude/settings.json` **não aceita** o campo `mcpServers` — o schema valida e rejeita a edição.
Os servidores MCP são guardados em `~/.claude.json` com a chave `mcpServers`.

O scope do `claude mcp add` controla onde fica:
- `--scope user` → `~/.claude.json` (global, disponível em todos os projetos e sessões)
- sem `--scope` (padrão: `local`) → `~/.claude.json` com chave de projeto (só naquele diretório)

**Fix no Makefile:** sempre passar `--scope user` no `xcode-mcp` para o servidor ser global.

**Check no skill:** buscar em `~/.claude.json` (campo `mcpServers`), não em `settings.json`.

---

## 2026-03-02 — Curly quotes quebram string interpolation Swift

Usar aspas tipográficas (`"` / `"`) dentro de string interpolation (`"\(var)"`) gera erro críptico do compilador:
`'any WritableKeyPath<_, _> & Sendable' cannot conform to FormatStyle`.
O parser do Swift interpreta a aspa tipográfica como delimitador de string aninhada.

**Fix:** usar aspas retas escapadas — `\"texto \(var)\"` — dentro de qualquer string interpolation.

---

## 2026-03-02 — Implementação fora do worktree: detectar CWD antes de criar arquivos

Ao executar um plano, o agente pode criar arquivos diretamente no `main` em vez do worktree se o CWD não for verificado antes.
Os arquivos ficam como unstaged em `main` e precisam ser copiados manualmente (`cp`) para o worktree antes do commit — o que funciona, mas é ruído desnecessário.

**Fix:** sempre checar `git branch --show-current` antes de criar qualquer arquivo. Deve retornar `feature/<nome>`. Se retornar `main`, mudar para o worktree primeiro.

---

## 2026-03-02 — markdownlint: fences aninhadas exigem outer fence com 4 backticks

Arquivos de skill (`.claude/commands/`) frequentemente mostram blocos de exemplo com fences dentro de fences.
markdownlint-cli2 v0.6.0 trata ` ```lang ` dentro de um bloco ` ``` ` como fechamento do bloco externo,
mesmo que CommonMark diga o contrário — isso gera erros MD040 e MD048 inesperados.

**Fix:** usar 4 backticks para o outer fence quando o conteúdo contém ` ``` ` internos.

Sintaxe: `````\`\`\`\`lang ... \`\`\`\``````

Tildes (`~~~`) resolvem o nesting mas violam MD048 (project exige backtick-only). Sempre usar 4 backticks.

---

## 2026-03-02 — Worktrees: escrever plan.md no worktree, não no main

Ao usar `/start-feature`, o `plan.md` deve ser escrito no path do worktree (`/worktrees/<feature>/...`), não no working tree do `main`.
Se escrito no `main` antes do worktree existir, o arquivo fica não-rastreado no branch errado — na hora do `git pull` após o merge,
git recusa com "untracked file would be overwritten". Fix: `rm` o arquivo do main e `pull` novamente.

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

## 2026-03-01 — task-orchestration: PTY input injection via `send(data:)` após delay

Para enviar texto automaticamente ao PTY depois que o processo inicializa, usar
`tv.send(data:)` com um `DispatchQueue.main.asyncAfter` de 1.5s. O delay dá tempo
para o processo imprimir seu prompt inicial antes da injeção.

```swift
if let input = initialInput {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak tv] in
        guard let tv else { return }
        tv.send(data: Array((input + "\n").utf8)[...])
    }
}
```

O `[weak tv]` evita retain cycle se a janela for fechada antes do timer disparar.
Não usar `[unowned tv]` — a janela pode ser dealocada no intervalo.

---

## 2026-03-01 — task-orchestration: SPM binary sem `.app` bundle não recebe keyboard events no macOS 14+

**Sintoma:** TextFields mostram anel de foco (SwiftUI + AppKit) mas teclado não responde.
Input vai para o Xcode ou para o processo em foreground.

**Causa:** app rodando como binário SPM puro não registra como app regular no macOS →
sem Dock icon → janelas não recebem keyboard events do OS mesmo com `@FocusState` e
`makeFirstResponder` corretos.

**Fix obrigatório em `applicationDidFinishLaunching`:**
```swift
NSApp.setActivationPolicy(.regular)
NSApp.activate(ignoringOtherApps: true)
```

**Por que as tentativas intermediárias falharam:**
- `@FocusState` — controla só o anel visual, não o AppKit first responder
- `makeKeyAndOrderFront` — funciona dentro do app, mas o OS não roteia keyboard sem activation policy correta
- `NSApp.activate` em `asyncAfter` — macOS 14+ ignora essa chamada fora de user interaction context
- Mover form para fora do `List` — correto para o problema de `NavigationSplitView`, mas não era o único problema

**Sintoma correlato:** `Cannot index window tabs due to missing main bundle identifier`
→ fix paralelo: embedar `Info.plist` via linker flag no `Package.swift`:
```swift
linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
                                "-Xlinker", "__info_plist", "-Xlinker", "ClaudeTerminal/App/Info.plist"])]
```
O `Info.plist` já existia em `ClaudeTerminal/App/Info.plist` — adicionar ao `exclude:` do target para silenciar warning de SPM.

---

## 2026-03-01 — task-orchestration: `NavigationSplitView` sidebar captura keyboard mesmo fora do `List`

`@FocusState` + `.focused()` num `TextField` dentro da coluna sidebar de `NavigationSplitView`
mostra o anel visual mas não recebe keyboard — a coluna sidebar tem um responder chain que
intercepta eventos antes do `TextField`.

**Fix:** mover o form para fora do `List` (para um `VStack` abaixo dele) não é suficiente.
A solução completa é usar `NSViewRepresentable` com `NSTextField` que chama
`window.makeFirstResponder(field)` diretamente — isso bypassa o responder chain do SwiftUI.

```swift
func makeNSView(context: Context) -> NSTextField {
    let field = NSTextField()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak field] in
        guard let field, let window = field.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
    }
    return field
}
```

---

## 2026-03-01 — task-orchestration: `zsh -l -i -c` para herdar PATH completo do usuário

Ao spawnar `claude` via `TerminalViewRepresentable`, um PATH hardcoded não inclui
tools instalados via `~/.local/bin`, nvm, pipx, etc. A solução é usar login+interactive shell:

```swift
args: ["-l", "-i", "-c", "cd '\(escaped)' && claude"]
```

- `-l` (login): carrega `/etc/zprofile` e `~/.zprofile`
- `-i` (interactive): carrega `~/.zshrc`
- Juntos: PATH idêntico ao que o usuário tem no seu terminal normal

Alternativa mais simples para outros casos: `ProcessInfo.processInfo.environment["PATH"]`
herda o PATH do processo pai — funciona se o app foi lançado de um terminal, mas não de Xcode.

---

## 2026-03-01 — hook-setup-onboarding: `.foregroundStyle(.accent)` não existe — usar `Color.accentColor`

`.accent` não é um membro válido de `ShapeStyle` no SwiftUI macOS 14+.
O correto é `Color.accentColor` como argumento direto:

```swift
// ERRADO
.foregroundStyle(.accent)

// CERTO
.foregroundStyle(Color.accentColor)
```

---

## 2026-03-01 — hook-setup-onboarding: enum com associated value cruzando boundary de ator precisa de `Sendable`

`HookInstallStatus` tem um case com associated value (`outdated(reason: String)`).
Ao retornar esse enum de um método de ator para `@MainActor` (ex: em `.task {}`),
o Swift 6 exige conformidade com `Sendable` — sem ela o compilador emite erro de concorrência.

`String` já é `Sendable`, então basta declarar:

```swift
public enum HookInstallStatus: Equatable, Sendable { ... }
```

Regra geral: todo tipo que cruza boundaries de isolamento (ator → MainActor) precisa ser `Sendable`.
Enums com associated values de tipos `Sendable` se tornam `Sendable` com a declaração explícita.

---

## 2026-03-01 — release-pipeline: SPM-only project não pode usar `xcodebuild archive`

`xcodebuild archive -project ClaudeTerminal.xcodeproj` falha com `does not exist` quando o repo é puro SPM (sem `.xcodeproj`).
`swift package generate-xcodeproj` foi removido no Xcode 14+ e não é uma alternativa viável.

**Pipeline correto para SPM + Developer ID + notarização:**

```bash
# 1. Build
swift build --configuration release

# 2. Montar .app manualmente
APP="$RUNNER_TEMP/ClaudeTerminal.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClaudeTerminal "$APP/Contents/MacOS/"
cp .build/release/ClaudeTerminalHelper "$APP/Contents/MacOS/"
cp ClaudeTerminal/App/Info.plist "$APP/Contents/"

# 3. Assinar — helper PRIMEIRO, bundle por ÚLTIMO
codesign --sign "Developer ID Application" --entitlements helper.entitlements \
  --options runtime --timestamp --force "$APP/Contents/MacOS/ClaudeTerminalHelper"

codesign --sign "Developer ID Application" --entitlements app.entitlements \
  --options runtime --timestamp --force "$APP"

# 4. Verificar
codesign --verify --deep --strict --verbose=2 "$APP"
```

**`--options runtime` + `--timestamp` são obrigatórios** — sem eles `xcrun notarytool submit` falha com
`"The executable does not have the Hardened Runtime enabled"`.

---

## 2026-03-01 — release-pipeline: `$(TEAM_ID)` em plists não é substituído automaticamente

`ExportOptions.plist` tinha `<string>$(TEAM_ID)</string>` — sintaxe de variável do Xcode build system,
não de plist. Em scripts de shell ou CI, esse valor chega literalmente como `$(TEAM_ID)`, causando falha
silenciosa na exportação.

**Solução:** substituir com `envsubst` ou `sed` antes de usar, ou passar o Team ID direto como string hardcoded
(ou via secret no CI usando `sed -i`). Para o pipeline SPM, `ExportOptions.plist` se tornou irrelevante —
usamos `codesign` diretamente.

---

## 2026-03-01 — release-pipeline: `rm cert.p12` logo após import do certificado

O certificado `.p12` decodificado fica no disco do runner entre o passo de import e o final do job.
Remover imediatamente após `security import` reduz a janela de exposição — a chave privada já foi
importada para o keychain, o arquivo `.p12` em disco não é mais necessário.

```bash
security import cert.p12 -k build.keychain -P "$CERT_PASSWORD" -T /usr/bin/codesign
rm cert.p12  # remover imediatamente — chave já está no keychain
```

---

## markdownlint

- Use `npx --yes markdownlint-cli2` to avoid requiring global install
- `MD013` (line length) needs `tables: false` and `code_blocks: false` to avoid false positives
- `MD024` (duplicate headings) should be disabled for `HANDOVER.md` — entries often have similar structure
- `MD041` (first heading must be h1) breaks templates with frontmatter or `<!-- TODO -->` comments

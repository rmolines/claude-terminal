# LEARNINGS.md — Technical learnings

Gotchas, limitations, and non-obvious behaviors discovered while working on this project.

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

## markdownlint

- Use `npx --yes markdownlint-cli2` to avoid requiring global install
- `MD013` (line length) needs `tables: false` and `code_blocks: false` to avoid false positives
- `MD024` (duplicate headings) should be disabled for `HANDOVER.md` — entries often have similar structure
- `MD041` (first heading must be h1) breaks templates with frontmatter or `<!-- TODO -->` comments

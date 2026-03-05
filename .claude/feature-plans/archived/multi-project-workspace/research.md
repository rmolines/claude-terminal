# Research: multi-project-workspace

## Descrição da feature

Transformar Claude Terminal de gerenciador de sessões de um único projeto em um workspace
multi-projeto onde cada repositório tem sua própria instância de Claude Code com estado
persistente — eliminando o overhead cognitivo de N janelas de terminal sem contexto
compartilhado. (Fonte: explore.md)

## Estado atual (main branch)

**Sem SwiftData** — todo estado é in-memory:
- `SessionManager`: actor com `[String: AgentSession]` keyed por `sessionID` somente
- `SessionStore`: `@Observable` que copia do actor para `@MainActor`
- `ClaudeAgent.swift` e `ClaudeTask.swift` existem mas são structs simples, não `@Model`

## Branch `worktree-fix-swiftdata-migration` — trabalho pronto

**1 commit à frente do ponto de divergência, 5 commits atrás do main atual** (sem PR aberto).

Já implementado nesse branch:

| Artefato | Status |
|---|---|
| `ClaudeProject` @Model | ✅ Completo — id, name, path (cwd), createdAt, sortOrder |
| `ClaudeTask` @Model | ✅ Completo — title, taskType, status, priority, sortOrder, project relationship |
| `ClaudeAgent` @Model | ✅ Completo — sessionID, status, worktreePath, branchName, startedAt, task relationship |
| SchemaV1 (snapshot frozen) | ✅ Completo — ClaudeTask + ClaudeAgent sem ClaudeProject |
| SchemaV2 (current) | ✅ Completo — +ClaudeProject, lightweight migration V1→V2 |
| AppMigrationPlan | ✅ Completo — `MigrationStage.lightweight(from: SchemaV1, to: SchemaV2)` |
| ClaudeTerminalApp (container) | ✅ Completo — `ModelContainer` compartilhado com `.modelContainer()` |
| DashboardView | ✅ Completo — janela principal com sidebar + TaskBacklogView |
| TaskBacklogView | ✅ Completo — List agrupada por projeto, seção "Other" para tarefas sem projeto |
| NewAgentSheet | ✅ Completo — task picker com priority labels, auto-fill repo path |
| Priority labels (P0–P3) | ✅ Completo — badges coloridos, sort por prioridade |

**Não implementado no branch (gap desta feature):**

| Gap | Impacto |
|---|---|
| `ClaudeProject.path == cwd` direto | 3 worktrees do mesmo repo = 3 projetos separados (vs. 1 projeto com 3 agentes) |
| Sem detecção de git root | Não agrupa worktrees do mesmo repo automaticamente |
| `SessionManager` sem link para `ClaudeProject` | Agentes aparecem no backlog, mas sessões live não apontam para projeto |
| Sem resiliência a `SessionStart` duplicado | `~/.claude.json` race condition pode criar sessão duplicada perdendo tokens acumulados |

## Arquivos existentes relevantes

- `Shared/IPCProtocol.swift` — `HookPayload.cwd` é `String` não-opcional; sempre presente
- `ClaudeTerminal/Services/SessionManager.swift` — keyed por `[sessionID: AgentSession]`; `cwd` está em `AgentSession` mas não usado para agrupamento
- `ClaudeTerminal/Services/HookIPCServer.swift` — pipeline de eventos; nenhuma mudança necessária para esta feature
- `ClaudeTerminalHelper/HookHandler.swift` — já extrai e passa `cwd`; nenhuma mudança

## Padrões identificados

- Todas as propriedades de relacionamento SwiftData devem ser `var` e `Optional` (não `let`, não non-optional)
- `@preconcurrency import SwiftData` necessário em `AppMigrationPlan.swift`, `SchemaV1.swift`, `SchemaV2.swift`
- `sortOrder: Int` obrigatório em todos os `@Model` — SwiftData não preserva order de arrays
- Nome das inner classes em `SchemaV1` DEVE ser igual ao entity name no store ("ClaudeTask", não "ClaudeTaskV1")
- `#Predicate` para filtrar por relacionamento: usar `persistentModelID`, não `id`
- `@Relationship(deleteRule: .cascade, inverse: \ClaudeAgent.task)` para Task→Agent; `.nullify` para Project→Task

## Dependências externas

SwiftData — built-in no Swift 6 / Xcode 16+. Nenhum package adicional necessário.

## Hot files que serão tocados

- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — adicionar ModelContainer
- `ClaudeTerminal/Services/SessionManager.swift` — ⚠️ adicionar lookup de ClaudeProject por cwd/git-root
- `ClaudeTerminal/Models/ClaudeAgent.swift` — migrar de struct para @Model
- `ClaudeTerminal/Models/ClaudeTask.swift` — migrar de struct para @Model
- `ClaudeTerminalHelper/HookHandler.swift` — possivelmente `isManagedByApp` (verificar se ainda existe)

## Riscos e restrições

1. **Rebase do branch**: `worktree-fix-swiftdata-migration` é 5 commits atrás do main. Os 5 commits são docs/skills (.claude/commands, rules, ux-identity, backlog.json). Conflitos esperados: baixos (sem overlap em código Swift).

2. **Projeto = cwd vs. git root**: O branch usa `path = cwd` diretamente. Para o caso de worktrees, a opção correta é detectar o git root via `git -C <cwd> rev-parse --show-toplevel`. A implementação correta:
   - `ClaudeProject.path` = git root (não cwd)
   - `ClaudeAgent` armazena o cwd real (para exibir a branch/worktree)
   - Múltiplos agentes com cwds diferentes mas mesmo git root → mesmo projeto

3. **Concorrência SwiftData**: `ModelContext` não é thread-safe. `SessionManager` é um actor separado do `@MainActor`. Link entre SessionManager e SwiftData deve passar por `persistentModelID` como bridge.

4. **`isManagedByApp` remoção**: O `IPCProtocol.swift` diff indica que esse campo foi removido de `AgentEvent` em algum ponto. Verificar antes de editar arquivos que dependem desse campo.

## Fontes consultadas

- `git show worktree-fix-swiftdata-migration:ClaudeTerminal/Models/*.swift` (via codebase reader)
- HackingWithSwift: SwiftData VersionedSchema, relationships, predicates
- Apple Developer: NavigationSplitView, SwiftData concurrency
- explore.md: arquitetura e constraints documentadas

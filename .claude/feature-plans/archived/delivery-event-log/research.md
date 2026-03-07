# Research: delivery-event-log

## Descrição da feature

Aba Kanban read-only no app Swift: 3 colunas (Todo/Doing/Done), features agrupadas por
milestone, atualização automática quando `backlog.json` muda em disco. O app é só um
reader — skills continuam editando o JSON.

## Arquivos existentes relevantes

- `ClaudeTerminal/Services/WorkflowStateReader.swift` — parser de backlog.json; structs
  `BacklogFile`, `BacklogMilestone`, `BacklogFeature` são **private** e anêmicas (id,
  status, prNumber apenas). Não tocar — seria over-reach; criar modelos independentes.
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — define `TabView` e
  `enum ProjectTab` com 4 tabs (terminal, skills, worktrees, workflow). Aqui se adiciona
  o 5º tab `kanban`.
- `ClaudeTerminal/Features/Workflow/WorkflowGraphView.swift` — padrão de referência para
  poll loop (`.task { while true { await sync(); sleep(30s) } }`) e leitura de backlog.
- `.claude/backlog.json` — schema atual dos dados; see below.

## Padrões identificados

- Tabs em `ProjectDetailView` usam `enum ProjectTab: String` local com cases simples.
  Adicionar novo case é cirúrgico: 1 linha no enum + 1 bloco `.tabItem {}` no `TabView`.
- Poll de 30s via `.task { }` é o padrão estabelecido — usar para auto-refresh do kanban.
- `List { ForEach { ... .onTapGesture {} } }` em vez de `List(selection:)` para evitar
  conflito com `persistentModelID` de @Model (padrão de `MainView`). Para o kanban (sem
  SwiftData), pode usar `List` normalmente, mas HStack de colunas é mais adequado.
- `@MainActor` em todos os services e views que tocam estado.

## Schema atual do backlog.json (feature object)

```json
{
  "id": "hook-pipeline",
  "title": "Hook pipeline end-to-end",
  "status": "pending | in-progress | done",
  "milestone": "m1",
  "path": "deep | fast | discover",
  "dependencies": ["other-feature-id"],
  "branch": "feature/hook-pipeline",
  "prNumber": 3,
  "startedAt": "2026-02-28",
  "completedAt": "2026-02-28",
  "createdAt": "2026-02-28"
}
```

Milestone object:

```json
{
  "id": "m4",
  "name": "M4 — Developer workflow",
  "objective": "...",
  "status": "active | planned | done",
  "completedAt": null
}
```

## Dependências externas

Nenhuma — feature é 100% SwiftUI + Foundation.

## Hot files que serão tocados

- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — adicionar enum case e tab
  (não é hot file listado no CLAUDE.md; mudança cirúrgica)
- `ClaudeTerminal/Services/WorkflowStateReader.swift` — **NÃO tocar** (risco de quebrar
  WorkflowGraphView)

## Arquivos novos a criar

- `ClaudeTerminal/Features/Kanban/KanbanView.swift` — view principal com 3 colunas
- `ClaudeTerminal/Features/Kanban/BacklogKanbanModels.swift` — structs Decodable
  independentes: `KanbanBacklogFile`, `KanbanMilestone`, `KanbanFeature`

## Campos novos no modelo kanban (apenas nos modelos do kanban — não altera JSON)

`BacklogKanbanModels.swift` decodifica todos os campos do backlog.json que existem hoje
mais os 3 novos (opcionais, backward-compatible):

| Campo | Tipo | Novo? | Uso |
|---|---|---|---|
| `id` | `String` | não | identificador |
| `title` | `String` | não | texto do card |
| `status` | `String` | não | coluna (pending/in-progress/done) |
| `milestone` | `String` | não | agrupamento |
| `prNumber` | `Int?` | não | badge no card |
| `branch` | `String?` | não | tooltip opcional |
| `labels` | `[String]?` | **sim** | chips coloridos no card |
| `sortOrder` | `Int?` | **sim** | ordenação dentro da coluna |
| `updatedAt` | `String?` | **sim** | timestamp para "last changed" |

Skills antigas que não emitem esses campos: `?? nil` / default — 100% backward-compatible.
O JSON em disco **não precisa** ser alterado; campos ausentes simplesmente ficam nil.

## Riscos e restrições

- `BacklogMilestone.name` não existe nos structs atuais (só `id`) — os modelos kanban
  precisam decodificar `name` para mostrar headers de milestone. OK nos novos structs.
- Poll de 30s pode parecer lento se o usuário rodar `close-feature` e querer ver
  imediatamente. Aceitável para v1 — fora do escopo melhorar para file watching.
- 3-column Kanban com `ScrollView(.horizontal)` + `HStack(alignment: .top)` é o layout
  mais simples. Evitar `LazyHGrid` — desnecessário para N < 100 cards.
- `createdAt` como fallback de ordenação quando `sortOrder == nil` — parser precisa lidar
  com ambos os formatos de data ("2026-02-28" e ISO 8601 completo).

## Fontes consultadas

Codebase local — sem web search necessário (feature é 100% SwiftUI interno).

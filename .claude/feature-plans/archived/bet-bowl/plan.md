# Plan: bet-bowl

## Problema

Dev que usa múltiplos agentes Claude Code em paralelo não tem lugar rápido para anotar
ideias de features enquanto está focado em outro trabalho. O backlog de tasks (ClaudeTask)
é pesado demais para captura efêmera — exige tipo, prioridade, projeto. A bet-bowl resolve
isso com captura em 1 campo + sorteio para decidir o que construir a seguir.

## Arquivos a criar

- `ClaudeTerminal/Models/Bet.swift` — `@Model final class Bet` com todos os campos
- `ClaudeTerminal/Models/SchemaV3.swift` — versão 3.0.0, inclui `Bet.self`
- `ClaudeTerminal/Features/TaskBacklog/BetDrawSheet.swift` — sheet de sorteio com Convert/Re-draw/Dismiss

## Arquivos a modificar

- `ClaudeTerminal/Models/AppMigrationPlan.swift` — adicionar SchemaV3 + stage V2→V3 lightweight
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — incluir `Bet.self` no Schema + migration plan
- `ClaudeTerminal/Features/TaskBacklog/TaskBacklogView.swift` — Bet Bowl section + inline form + sheet

## Passos de execução

### 1. Criar `Bet.swift`

```swift
@Model
final class Bet {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var status: String = "draft"   // "draft" | "converted"
    var createdAt: Date = Date()
    var convertedTaskID: UUID?     // link fraco após conversão
    var sortOrder: Int = 0

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.sortOrder = 0
    }
}
```

Sem campo `drawnAt` / status `"drawn"` na v1 — simplifica o fluxo (apenas draft → converted).

### 2. Criar `SchemaV3.swift`

```swift
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self, Bet.self]
    }
}
```

Sem inner classes congeladas — Bet é entidade nova, não precisa preservar entity name de store
antigo (não existia no V2 store). Lightweight migration cria a tabela automaticamente.

### 3. Atualizar `AppMigrationPlan.swift`

- Adicionar `SchemaV3.self` ao array `schemas`: `[SchemaV1.self, SchemaV2.self, SchemaV3.self]`
- Adicionar `migrateV2toV3`:

```swift
static let migrateV2toV3 = MigrationStage.lightweight(
    fromVersion: SchemaV2.self,
    toVersion: SchemaV3.self
)

static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3] }
```

### 4. Atualizar `ClaudeTerminalApp.swift`

- `Schema([ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self, Bet.self])`
- Manter `migrationPlan: AppMigrationPlan.self` — já presente.

### 5. Criar `BetDrawSheet.swift`

Sheet que recebe `Bet?` (a bet sorteada) e oferece:
- Título grande da bet
- Botão "Convert to Task" → `context.insert(ClaudeTask(title: bet.title, ...))`, `bet.status = "converted"`, `bet.convertedTaskID = task.id`, `try? context.save()`, fechar sheet
- Botão "Re-draw" → sorteia nova bet aleatória do array passado (callback ou binding)
- Botão "Dismiss" → fechar sem mudar estado

### 6. Atualizar `TaskBacklogView.swift`

Adicionar ao estado da view:
```swift
@Query(sort: \Bet.sortOrder) private var bets: [Bet]
@State private var isAddingBet = false
@State private var newBetTitle = ""
@State private var drawnBet: Bet? = nil
@State private var showingDrawSheet = false
```

Adicionar ao `List` (após os groups de tasks, como nova Section):
```swift
Section(header: betBowlHeader) {
    if draftBets.isEmpty {
        Text("No bets yet — tap + to capture an idea")
            .font(.callout).foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
    } else {
        ForEach(draftBets) { bet in BetRow(bet: bet) }
            .onDelete { offsets in deleteBets(at: offsets) }
    }
}
```

Header com [+] e [Draw] (Draw disabled quando < 2 draft bets):
```swift
private var betBowlHeader: some View {
    HStack {
        Text("Bet Bowl").font(.caption.bold()).foregroundStyle(.secondary)
        Spacer()
        Button { draw() } label: { Image(systemName: "dice") }
            .disabled(draftBets.count < 2)
        Button { isAddingBet = true; newBetTitle = "" } label: { Image(systemName: "plus") }
            .disabled(isAddingBet)
    }
    .textCase(nil)
}
```

Adicionar `newBetForm` (abaixo de `newTaskForm`, mesmo padrão com AutoFocusTextField).

Adicionar computed var:
```swift
private var draftBets: [Bet] { bets.filter { $0.status == "draft" } }
```

Adicionar `.sheet(isPresented: $showingDrawSheet)` para BetDrawSheet.

Adicionar mutations `commitNewBet()`, `deleteBets(at:)`, `draw()`.

Atualizar preview container para incluir `Bet.self`.

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: `ClaudeTerminalApp.swift` — adicionar Bet.self ao schema
- [ ] Novas dependências: não

## Rollback

```bash
# Reverter arquivos criados e modificados
git checkout -- ClaudeTerminal/Models/AppMigrationPlan.swift
git checkout -- ClaudeTerminal/App/ClaudeTerminalApp.swift
git checkout -- ClaudeTerminal/Features/TaskBacklog/TaskBacklogView.swift
rm ClaudeTerminal/Models/Bet.swift
rm ClaudeTerminal/Models/SchemaV3.swift
rm ClaudeTerminal/Features/TaskBacklog/BetDrawSheet.swift
```

Se o store já foi migrado para V3, deletar o banco em
`~/Library/Application Support/ClaudeTerminal/` antes de reverter.

## Learnings aplicados

- **SwiftData entity name mismatch**: SchemaV1 inner classes devem ter o mesmo nome da entidade
  no store. Para `Bet` (entidade nova), não há inner classes congeladas — SwiftData cria a tabela
  do zero via lightweight migration.
- **Non-optional sem default value**: todos os campos não-opcionais de `Bet` têm `= default`
  (ex: `var status: String = "draft"`) — necessário para lightweight migration popular novas rows.
- **`sortOrder` manual obrigatório**: `Bet` tem `var sortOrder: Int = 0` + `@Query(sort: \Bet.sortOrder)`.
- **`context.save()` explícito**: após cada insert/delete de `Bet`.
- **AutoFocusTextField**: reutilizado para newBetForm — já resolve o problema de first responder no sidebar.
- **Curly quotes**: atenção a `\"` escaped em toda string interpolation dentro de labels.
- **`context.save()` após conversão**: na conversão bet→task, salvar após ambos os inserts/updates.

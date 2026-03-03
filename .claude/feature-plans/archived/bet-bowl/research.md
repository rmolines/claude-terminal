# Research: bet-bowl
_Gerado em: 2026-03-03_

## Descrição da feature

Sistema de captura rápida de ideias ("bets" no vocabulário de Shape Up) inspirado em um vaso
de sorteio estilo Copa do Mundo. O usuário pode anotar uma ideia em segundos enquanto está
focado em outro agente. Quando quiser decidir o que construir a seguir, um mecanismo de
"sorteio" seleciona uma bet aleatoriamente (com peso por appetite/prioridade) e a converte
em task/feature para despachar para um agente.

## Arquivos existentes relevantes

- `ClaudeTerminal/Models/ClaudeTask.swift` — modelo de referência para criar `Bet.swift` (padrões: var, Optional, sortOrder)
- `ClaudeTerminal/Models/SchemaV2.swift` — schema atual (frozen; SchemaV3 será criado ao lado)
- `ClaudeTerminal/Models/AppMigrationPlan.swift` — adicionar stage V2→V3
- `ClaudeTerminal/Features/TaskBacklog/TaskBacklogView.swift` — CRÍTICO: onde a bet-bowl section entra; reutilizar AutoFocusTextField e padrão de form
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — adicionar `Bet.self` ao ModelContainer
- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — NavigationSplitView (pode precisar de ajuste mínimo de layout)

## Padrões identificados

- **SwiftData:** `@Model final class` com `var` em tudo, Optional em relacionamentos, `sortOrder: Int` em toda entidade com arrays
- **Mutations:** sempre `context.insert()` + `context.save()` explícito — auto-save não confiável
- **Quick entry:** `AutoFocusTextField` (NSViewRepresentable) já existe e pega first responder no appear — reutilizar
- **Form pattern:** `@State private var isAddingBet = false` → show inline form → commit/cancel
- **@Query:** sort por `sortOrder`, filter por status em views SwiftData-native
- **Naming:** prefixar entidades com domínio quando houver risco de conflito (como `ClaudeTask` evitou `Task`)
- **Computed properties:** lógica de display (cor, label) como computed var — SwiftUI.Color não pode ser persistida

## Dependências externas

Nenhuma — tudo em Swift nativo + SwiftData.

## Hot files que serão tocados

- `ClaudeTerminal/Models/AppMigrationPlan.swift` — adicionar V2→V3
- `ClaudeTerminal/Features/TaskBacklog/TaskBacklogView.swift` — adicionar seção bet-bowl + form de captura
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — incluir `Bet.self` no schema
- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — ⚠️ CONFLITO POTENCIAL com worktree `agent-card-ui` (que toca AgentCardView + DashboardView)

## Proposta de modelo `Bet`

```swift
@Model
final class Bet {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?              // opcional: texto livre de contexto
    var status: String = "draft"    // "draft" | "drawn" | "converted"
    var createdAt: Date = Date()
    var drawnAt: Date?              // timestamp do sorteio
    var convertedTaskID: UUID?      // link fraco para ClaudeTask após conversão
    var sortOrder: Int = 0
}
```

Separado de `ClaudeTask` porque bets são captura efêmera — só viram task se vencidas no sorteio.

## Proposta de UX (Shape Up + bowl metaphor)

**Captura rápida:**
- Seção "Bet Bowl" no sidebar (abaixo ou acima das tasks, tab ou section header)
- Botão `+` abre inline form: AutoFocusTextField (título) + notes opcional + Cancel/Add
- Sem campos de prioridade na captura — só o título importa para anotar rápido

**Sorteio:**
- Botão "Draw" (ou ícone de bola/dado) aparece quando há ≥ 2 bets com status `draft`
- `BetDrawSheet` — sheet ou popover que mostra a bet sorteada com animação simples
- Opções pós-sorteio: "Convert to Task" | "Re-draw" | "Dismiss"
- Conversão: cria `ClaudeTask` com título da bet, marca bet como `converted`

**Sorteio ponderado (simples, v1):**
- Sem notas de peso — sorteio puro aleatório entre drafts na v1
- Peso pode vir na v2 se o usuário sentir necessidade (não over-engineer agora)

## Decisão de navegação

A bet-bowl fica como **nova seção dentro de `TaskBacklogView`** (sidebar), não como nova tab no DashboardView. Motivo: menor impacto em DashboardView (reduz conflito com `agent-card-ui`), e mantém o conceito de "backlog" centralizado na sidebar.

## Riscos e restrições

| Risco | Mitigação |
|---|---|
| SchemaV3 migration break em store existente | Lightweight migration com `@Model` puro — campo novo com `= ""` default |
| DashboardView overlap com agent-card-ui worktree | Minimizar toque em DashboardView — a bet-bowl fica toda em TaskBacklogView |
| AutoFocusTextField em sidebar não captura teclado | Já resolvido no projeto — `makeFirstResponder` via NSViewRepresentable existe |
| Curly quotes em string interpolation | Atenção ao escrever labels com `\"` escaped |
| `Bet` como nome de @Model | Sem conflito com Swift keywords — mas usar `Bet` direto (não `ClaudeBet`) |

## Fontes consultadas

- Shape Up (Basecamp): bets.not-backlogs, betting-table, place-your-bets
- macOS quick capture UX: Stik (open-source), padrões de float panel + global hotkey
- Weighted random selection: não há precedente no espaço de developer tools — sorteio puro é seguro para v1

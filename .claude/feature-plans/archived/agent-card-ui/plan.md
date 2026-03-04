# Plan: agent-card-ui

## Problema
A UI atual (NavigationSplitView com lista + split view) não permite ver múltiplos agentes
simultâneos. O usuário precisa alternar entre sessões para acompanhar o que cada agente faz
e responder HITL. Com 4-8 agentes rodando, o fluxo é fragmentado e lento.

## Arquivos a modificar

- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — substituir content pane por grid
- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — adaptar para embedded no card

## Arquivos a criar

- `ClaudeTerminal/Features/Dashboard/AgentCardView.swift` — componente de card

## Passos de execução

### 1. Criar `AgentCardView.swift`

Card de tamanho fixo (~100pt height) com:
- Status dot (verde/laranja/cinza/vermelho)
- cwd truncado (`.truncationMode(.middle)`)
- `currentActivity` como "contexto" (já populado dos hooks)
- Timer via `TimelineView(.periodic(from: .now, by: 1.0))`
- Token badge (formato atual reutilizado)
- Sub-agent count badge se `> 0`
- Estado HITL: quando `status == .awaitingInput`, substituir activity line por
  botões **Approve** / **Reject** com ações `Task { await SessionManager.shared.approveHITL() }`
- `@State var showTerminal: Bool` + `.popover(isPresented: $showTerminal) { AgentTerminalView(session: session) }`
- Tap gesture no card (fora dos botões) → `showTerminal = true`

### 2. Adaptar `HITLPanelView.swift`

O `HITLPanelView` atual tem frame fixo de 400pt e título "Approval Required" — é para
uso como sheet. Para o card, não usaremos o HITLPanelView diretamente; a lógica de botões
é inlinada no `AgentCardView` para manter o tamanho fixo do card.
(Nenhuma mudança necessária no HITLPanelView — fica disponível para uso futuro como sheet.)

### 3. Atualizar `DashboardView.swift`

- Remover a coluna `content` do `NavigationSplitView` (List de SessionRows)
- Substituir por `ScrollView` com `LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12)`
- Iterar `sortedSessions` renderizando `AgentCardView` por sessão
- Remover `@State private var selectedSessionID` (seleção agora é por popover no card)
- Manter sidebar (`TaskBacklogView`) e toolbar iguais
- Remover coluna `detail` (AgentTerminalView sai do split view; vai para popover no card)
- Ajustar `NavigationSplitView` para 2 colunas: sidebar + grid content

### 4. Remover `SessionRow` e emptyState

`SessionRow` e `emptyState` ficam obsoletos com o novo layout. Remover do arquivo.
Manter os `#Preview` atualizados.

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] Dockerfile / imagem: não muda
- [ ] Config principal do projeto: não muda
- [ ] CI/CD: não muda
- [ ] Novas dependências: não

## Rollback

```bash
git -C .claude/worktrees/agent-card-ui revert HEAD
# ou
git checkout main -- ClaudeTerminal/Features/Dashboard/DashboardView.swift
```

## Learnings aplicados

- `TimelineView(.periodic(...))` dentro do card — padrão já confirmado como seguro em List rows
- Um `DispatchQueue` por instância de `LocalProcessTerminalView` — `TerminalViewRepresentable`
  já faz isso; popover não muda essa garantia
- `Task { await SessionManager.shared.approveHITL() }` de `@MainActor` view é o padrão correto
- Card tap e botão HITL precisam de `simultaneousGesture` ou HitTest separado para não colidir

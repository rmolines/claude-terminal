# Plan: hitl-floating-nspanel

## Problema

`HITLPanelView` existe mas não é usada como NSPanel — os controles HITL ficam inline no
`AgentCardView`. O painel precisa aparecer sobre qualquer janela (inclusive apps externos)
via `NSPanel` com `level = .floating`, para que o usuário possa aprovar/rejeitar sem precisar
trazer o Claude Terminal para frente.

## Arquivos a modificar

- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — criar: controller
  `@MainActor` que gerencia ciclo de vida do NSPanel, observa SessionStore, mostra/oculta
  o panel via `withObservationTracking`
- `ClaudeTerminal/App/AppDelegate.swift` — adicionar propriedade `hitlPanelController` e
  inicializá-la em `applicationDidFinishLaunching`

## Passos de execução

1. Criar `HITLFloatingPanelController.swift` com:
   - NSPanel: `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`,
     `hidesOnDeactivate = false`, `isReleasedWhenClosed = false`
   - `start()` — inicia `withObservationTracking` sobre `SessionStore.sessions`
   - `updatePanel()` — mostra panel se há sessão `.awaitingInput`, descarta se não há
   - `show(session:)` — cria/atualiza `NSHostingView<HITLPanelView>` e traz panel para frente
2. Modificar `AppDelegate.swift` (+3 linhas):
   - `private var hitlPanelController: HITLFloatingPanelController?`
   - `hitlPanelController = HITLFloatingPanelController()` em `applicationDidFinishLaunching`
   - `hitlPanelController?.start()`

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

```bash
rm ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift
git checkout ClaudeTerminal/App/AppDelegate.swift
```

## Learnings aplicados

- `hidesOnDeactivate = false` necessário para NSPanel persistir visível ao trocar de app
- `isReleasedWhenClosed = false` para reutilizar o mesmo panel sem recriar
- Mesmo padrão `withObservationTracking` usado em `AppDelegate.observeSessionStore()`
- `NSHostingView.sizingOptions = [.minSize]` para auto-dimensionar a partir da view SwiftUI

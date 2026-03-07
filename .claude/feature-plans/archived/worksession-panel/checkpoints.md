## Checkpoint 1 — Deliverable 1 (Walking Skeleton)
_2026-03-06T18:07:05Z_

### O que foi construído
`WorkSession.swift` (struct + UrgencyTier), `WorkSessionService.swift` (singleton @MainActor, poll 2s, join worktree↔session↔kanban), `WorkSessionPanelView.swift` (List + urgency dots), `ProjectDetailView.swift` (+tab Sessions). Aba Sessions visível e funcional com worktrees reais ordenadas por urgência.

### Assunções validadas
- [verified] Localização D (tab dentro do projeto) — confirmado pelo usuário antes de implementar
- [verified] WorkSession runtime-only com id = worktree.path — implementado e testado
- [verified] Poll timer 2s + snapshot SessionStore — implementado e testado

### Assunções ainda em aberto
- [assumed] Join via `hasPrefix` entre session.cwd e worktree.path — usuário não reportou falha, mas não confirmou explicitamente todos os casos
- [assumed] Performance com N worktrees — não medida formalmente
- [assumed] KanbanReader.load síncrono e rápido o suficiente — não causou problema visível

### Resposta do usuário
> avança sim

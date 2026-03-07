# Plan: delivery-event-log

## Problema

Dev solo precisa ver, num relance, quais features estão em cada fase (Todo/Doing/Done)
agrupadas por milestone — sem abrir backlog.json no terminal. A aba kanban é a ponte
entre "dado em disco" e "visibilidade no app".

## Assunções

<!-- status: [assumed] = não verificada | [verified] = confirmada | [invalidated] = refutada -->
<!-- risco:   [blocking] = falsa bloqueia a implementação | [background] = emerge naturalmente -->

- [verified][blocking] `ProjectDetailView.swift` usa `enum ProjectTab: String` local —
  adicionar `case kanban` é cirúrgico
- [verified][blocking] `backlog.json` tem `title`, `milestone`, `prNumber`, `status`,
  `createdAt` nos objects de feature — suficientes para o card sem novos campos
- [verified][background] `labels` e `sortOrder` não existem no JSON atual — decodificar
  como optional com default nil; cards sem labels simplesmente não mostram chips
- [assumed][background] Poll de 30s via `.task {}` é suficiente para v1 de auto-refresh

## Questões abertas

**Explicitamente fora do escopo (evitar scope creep):**

- File watching nativo (FSEvents) em vez de poll — v1 usa 30s poll
- Drag-and-drop de cards
- Pitches e icebox no kanban
- Edição de features no app

## Deliverables

### Deliverable 1 — Modelos + KanbanView básico

**O que faz:** Novos structs Decodable para o kanban + view com 3 colunas mostrando
cards agrupados por milestone a partir de backlog.json do projeto selecionado.

**Critério de done:** Abrir o app com um projeto que tem backlog.json → aba "Kanban"
mostra features nas colunas corretas com título + prNumber (se existir). Sem crash, sem
dados fantasma.

**Valida:** assunção sobre campos existentes em backlog.json; assunção sobre layout HStack

**⚠️ Execute `/checkpoint` antes de continuar para o Deliverable 2.**

### Deliverable 2 — Tab integration + auto-refresh

**O que faz:** Adiciona aba "Kanban" ao `ProjectDetailView`, poll de 30s para re-ler
backlog.json, e estado vazio quando não há backlog.json no projeto.

**Critério de done:** Aba aparece na barra de tabs; ao rodar `close-feature` e esperar
~30s, o card some de "Doing" e aparece em "Done" sem reiniciar o app. Projeto sem
backlog.json mostra placeholder em vez de crash.

## Arquivos a modificar

- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — enum + tab item [D2]

## Arquivos a criar

- `ClaudeTerminal/Features/Kanban/BacklogKanbanModels.swift` — structs Decodable [D1]
- `ClaudeTerminal/Features/Kanban/KanbanView.swift` — view principal [D1]

## Passos de execução

1. Criar `ClaudeTerminal/Features/Kanban/BacklogKanbanModels.swift` com structs
   `KanbanBacklogFile`, `KanbanMilestone`, `KanbanFeature` + `KanbanReader` que lê
   backlog.json do path do projeto [D1]
2. Criar `ClaudeTerminal/Features/Kanban/KanbanView.swift` — layout 3 colunas (HStack +
   ScrollView vertical por coluna), cards agrupados por milestone, poll 30s [D1]
3. ⚠️ Execute `/checkpoint` — Deliverable 1 concluído
4. Editar `ProjectDetailView.swift`: adicionar `case kanban` ao enum `ProjectTab` e
   novo `.tabItem {}` com `KanbanView(project: project)` [D2]
5. Adicionar estado vazio ("Sem backlog.json neste projeto") ao KanbanView [D2]
6. Build + testes manuais

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

```bash
git revert HEAD  # ou deletar os 2 arquivos novos + reverter ProjectDetailView.swift
```

## Learnings aplicados

- `List(selection:)` com @Model crashava silenciosamente — kanban não usa SwiftData,
  mas ainda assim usar HStack de colunas em vez de List para evitar problemas futuros
- `@MainActor` obrigatório em todos os services de leitura (padrão do projeto)
- Poll 30s via `.task { while !Task.isCancelled { ... sleep ... } }` — padrão
  estabelecido em WorkflowGraphView

# Discovery: delivery-event-log
_Gerado em: 2026-03-06_

## Problema real

O `backlog.json` existe como tracker de features/milestones, mas não há nenhuma interface
que mostre o estado do projeto de forma visual. O dev precisa abrir o JSON no terminal
para saber o que está pending, in-progress ou done. Além disso, campos necessários para
uma view kanban (sortOrder, labels) ainda não existem no schema.

## Usuário / contexto

Dev solo usando Claude Terminal como Mission Control para agentes paralelos. Quer ver,
num relance, quais features estão em cada fase — sem abrir arquivo de texto. A fonte
de verdade continua sendo o `backlog.json` editado pelas skills; o app é só um reader.

## Alternativas consideradas

| Opção | Por que não basta |
|---|---|
| Ler o backlog.json no terminal com jq | Já é possível, mas não é uma view — é um dump de texto sem hierarquia visual |
| events.jsonl como fonte de verdade | Over-engineering para o objetivo atual; o backlog.json já tem o estado certo, só falta a view |
| Kanban editável no app | Scope creep — skills são o editor canônico; o app como editor cria conflito de fonte de verdade |
| Unificar pitches/icebox/features numa view só | Fora do escopo agora; o usuário quer ver só features dentro de milestones |

## Por que agora

O backlog já existe e tem dados estruturados. A aba kanban é a ponte entre "dado em disco"
e "visibilidade para o dev". Sem ela, o app é só um monitor de agentes — não um
Mission Control do projeto.

## Escopo da feature

### Dentro

- Aba "Kanban" no app Swift (read-only)
- 3 colunas: **Todo** (`pending`), **Doing** (`in-progress`), **Done** (`done`)
- Cards agrupados por milestone (seção por milestone na coluna)
- Card mostra: título, labels (se existirem), PR number (se existir)
- Atualização automática quando `backlog.json` muda em disco
- Schema evolution mínimo: `sortOrder`, `labels`, `updatedAt` por feature — adicionados
  com defaults seguros (backward-compatible, skills antigas continuam funcionando)
- `WorkflowStateReader.swift` atualizado para decodificar os novos campos

### Fora (explícito)

- Drag-and-drop / reordenação de cards no app
- Criação ou edição de features no app
- events.jsonl / audit trail de transições
- Correção de dados históricos (startedAt null em features antigas)
- Pitches e icebox no kanban
- mergedAt distinto de completedAt (baixa prioridade dado o foco)
- Qualquer forma de sync bidirecional app → backlog.json

## Critério de sucesso

- Abrir o app e ver as features do backlog.json organizadas em colunas Todo/Doing/Done,
  agrupadas por milestone, sem abrir nenhum arquivo de texto
- Quando uma skill roda `close-feature` e atualiza `backlog.json`, a aba kanban reflete
  a mudança sem precisar reiniciar o app

## Riscos identificados

- `WorkflowStateReader.swift` tem `BacklogFeature` struct com campos hardcoded — novos
  campos e status values exigem atualização coordenada no Swift e no schema
- `sortOrder` calculado por skills tem race condition em multi-agent; para read-only kanban,
  `createdAt` pode ser fallback de ordenação sem exigir que as skills calculem sortOrder
- O app já tem uma estrutura de tabs? Precisa verificar antes de planejar a navegação

# Explore: Workflow leve para múltiplas pequenas entregas

## Pergunta reframeada

Como executar N melhorias pequenas e heterogêneas (bugs, UX polish, refactors) com micro-commits
individuais, agrupadas num único PR, sem o overhead do ciclo completo start/ship/close por item?

## Premissas e o que não pode ser

- **Premissa implícita 1:** cada melhoria precisa do mesmo nível de planejamento que uma feature — FALSO. A overhead está no ritual, não na implementação.
- **Premissa implícita 2:** worktrees separados por tarefa são necessários — FALSO para tarefas que não competem pelos mesmos arquivos.
- **Premissa implícita 3:** o histórico de commits deve ter granularidade de PR — FALSO. O histórico pode ter granularidade de tarefa dentro de um único PR.
- **Constraint — o que não pode ser a solução:** commits direto no main sem PR (viola git-workflow.md). Um único commit "cleanup" gigante (impossível de reverter seletivamente). Eliminar commits por tarefa (perde rastreabilidade).

## Mapa do espaço

**Skills existentes que tocam o problema:**
- `/fix` — próximo, mas: cria worktree por bug, tem fases de diagnóstico (1 e 2), ship e close separados
- `/start-feature` (fast mode) — cria worktree, gera mini plan.md, executa — ainda é 1 feature = 1 PR
- `/checkpoint` — faz commit intermediário dentro de um deliverable; não abre PR

**Padrão nativo do git que resolve exatamente isso:**
- Uma branch `chore/polish-<data>` + N commits convencionais + 1 PR = o padrão canônico de "batch PR"
- O que falta é a skill que orquestra isso com a checklist de tarefas e o micro-commit por item

**Análogo em outros workflows:**
- "Sprint de dívida técnica" no Shape Up — blocos de tempo dedicados a N pequenos itens sem ciclo de pitch por item
- "Stacked diffs" (Graphite, git-town) — N commits independentes que vivem numa branch, cada um revisável

## O gap

- Não existe skill de "sessão de polish" que abra uma branch uma vez e itere por uma checklist de itens
- O `/checkpoint` faz commit mas não gerencia lista de tarefas nem abre PR
- O `/fix` é ótimo para um bug com causa raiz incerta; ruim para "20 coisas que já sei o que fazer"
- Nenhuma skill atual separa **granularidade de commit** (por tarefa) de **granularidade de PR** (por batch)

## Hipótese

Uma skill `/polish` que funciona como "sessão de cleanup": recebe uma lista de tarefas upfront
(ou vai construindo durante a sessão), abre uma branch `chore/polish-<data>` uma única vez,
e para cada item executa → micro-commit → próximo. No final, um único PR com todos os commits
preservados (não squash) para manter rastreabilidade por item.

**Como chegamos aqui:**
- Descartado: uma skill por tarefa com PR separado — o overhead é exatamente o que o usuário quer evitar
- Descartado: squash no merge — perde a granularidade de "qual commit resolveu qual item" que micro-commits dão
- Tensão resolvida: independência vs. dependência entre tarefas — na mesma branch, dependências são naturais; a skill não precisa isolar, só sequenciar

**Stress-test:** Se uma tarefa do batch introduz um bug, o PR inteiro fica bloqueado. Com PRs separados, as outras tarefas poderiam ser mergeadas independentemente. Resposta: para tarefas com risco de regressão, o usuário ainda pode abrir PRs separados — `/polish` é o caminho certo para itens de baixo risco que se beneficiam de velocidade.

## Proxima acao

**Veredicto:** melhoria em existente — criar nova skill `/polish` no projeto

**Proxima skill:** `/start-feature polish-sprint`
**Nome sugerido:** `polish-sprint`

**O que ficou consolidado:**
- A skill deve abrir worktree uma vez, não por tarefa
- Commits devem ser preservados (não squash) para rastreabilidade por item
- O PR abre no final da sessao, nao por tarefa

---
Faca `/clear` para limpar a sessao e entao rode `/start-feature polish-sprint`.
O contexto esta preservado em `.claude/feature-plans/polish-sprint/explore.md`.
---

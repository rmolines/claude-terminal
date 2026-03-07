# Discovery: polish-kanban-integration

_Gerado em: 2026-03-06_

## Problema real

Sessoes de `/polish` sao invisíveis para o projeto apos o fato. `/project-compass` nao consegue
dizer "na semana passada houve 3 polishes que cobriram 12 itens". O `backlog.json` so conhece
milestones e features — polish sprints nao deixam rastro no kanban.

## Usuario / contexto

Dev solo usando Claude Terminal como Mission Control para agentes Claude Code. Roda `/polish`
regularmente para melhorias incrementais. Hoje, apos um polish sprint, roda `/project-compass`
e nao ve nenhum sinal de que o sprint aconteceu — so os commits/PR no git, difíceis de acessar
programaticamente pelas skills.

## Alternativas consideradas

| Opcao | Por que nao basta |
|---|---|
| Sync bidirecional entre os tres sistemas (polish/tasks/backlog) | Conflitos e drift superam o benefício. Native tasks sao working memory — escreve-las no kanban degrada o sinal do projeto. |
| Arquivo separado `chores.json` | `/project-compass` passa a ler dois arquivos; aumenta superficie de falha em worktrees; viola single-source-of-truth |
| Polish como pseudo-feature no array `features[]` | Conflito conceitual — polish nao tem milestone, startedAt, dependency graph. Pollui o schema de features. |
| Status live via consulta ao GitHub | Adiciona dependencia de rede; complexidade nao justificada para historico simples |

## Por que agora

`/project-compass` e usada como orientacao em todo milestone. Enquanto polish sprints forem
invisíveis, o dashboard de estado do projeto fica incompleto — o dev nao consegue responder
"o que fizemos de melhoria tecnica neste ciclo?" sem ir ao git manualmente.

## Escopo da feature

### Dentro

- Array `chores[]` no `backlog.json` (aditivo, sem migration)
- `/polish` escreve um registro no `chores[]` logo apos abrir o PR (post-facto, append-only)
- `/polish` ganha fase de close (`/polish --close`) que atualiza `status: "merged"` e remove worktree
- `/polish` test step melhorado: build + testes automaticos + `RenderPreview` (Xcode MCP) para
  itens que tocaram UI; checklist manual opcional ao final (nao por item)
- `/project-compass` exibe secao "Chores" com historico de polish sprints (data, PR, N itens)

### Fora (explícito)

- Native tasks (TaskCreate/TodoWrite) — sao working memory, nao project records; sem integracao
- Sync bidirecional entre qualquer combinacao dos tres sistemas
- Vinculo de chores a milestones — polish e ortogonal a milestones por design
- Atualizacao automatica de status via webhook ou hook `TaskCompleted`
- Rollover de itens skipped para o proximo polish sprint (pode ser feature futura)

## Criterio de sucesso

- Apos um polish sprint, `/project-compass` exibe uma secao "Chores" com pelo menos:
  data, numero do PR, quantidade de itens cobertos
- O registro persiste no `backlog.json` canônico mesmo quando `/polish` roda de dentro de worktree
- `/polish --close` atualiza o status do registro para `"merged"` e remove a worktree

## Schema do registro

```json
{
  "id": "polish-2026-03-06",
  "type": "polish",
  "date": "2026-03-06",
  "branch": "chore/polish-2026-03-06",
  "prNumber": 63,
  "prUrl": "https://github.com/rmolines/claude-terminal/pull/63",
  "status": "open",
  "items": ["Fix X", "Refactor Y"],
  "skipped": ["Item Z — mais complexo que esperado"]
}
```

## Arquivos a modificar

| Arquivo | O que muda |
|---|---|
| `.claude/commands/polish.md` | Passo de escrita no `chores[]` pos-PR; test step com build+RenderPreview; fase close (`--close`) |
| `.claude/commands/project-compass.md` | Nova secao "Chores" na Fase 1c (leitura) e Fase 3 (relatorio) |
| `.claude/backlog.json` | Adicionar `"chores": []` como array top-level (aditivo) |

## Riscos identificados

| Risco | Mitigacao |
|---|---|
| Worktree path — escrita relativa vai para a worktree deletada | `REPO_ROOT=$(git worktree list \| head -1 \| awk '{print $1}')` antes de qualquer write (padrao ja em `close-feature.md`) |
| `chores` key ausente no backlog existente | `jq '. + {chores: ((.chores // []) + [$entry])}'` — null-safe |
| `jq` nao disponível | Guard `command -v jq` + skip silencioso (espelhar `close-feature.md`) |
| `RenderPreview` so funciona com Xcode aberto | Instrucao no test step: avisar se MCP nao disponível, degradar para checklist manual |
| Dois commits simultaneos no `chores[]` | Append ao final do array — git merge limpo na pratica |

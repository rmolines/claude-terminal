# Research: skill-workflow-ux

## Descrição da feature

Redesign do workflow de skills para que o caso de uso mais comum (feature rápida, escopo claro)
não pague overhead de pesquisa e planejamento. Inverte o default do `/start-feature`: execução
direta vira padrão, discovery e pesquisa viram opt-in (`--discover`, `--deep`). Introduz
`backlog.json` como fonte da verdade substituindo `roadmap.md` + `sprint.md`. Adiciona skill
`/debug` para investigação sem commit. Torna `/close-feature` mais inteligente (detecta PR
merged e atualiza backlog.json).

Contexto completo em `discovery.md`.

## Arquivos existentes relevantes

### Skills de projeto (`.claude/commands/`)
- `.claude/commands/start-feature.md` — skill principal a redesenhar; atualmente: 4 fases (0, A, B, C), flags `--discover` e `--fast`, detecção por arquivo
- `.claude/commands/close-feature.md` — precisa de: auto-detecção de PR merged, update em backlog.json
- `.claude/commands/start-milestone.md` — lê `roadmap.md` + gera `sprint.md`; precisará ler `backlog.json` como fonte (ou ser declarada "deprecated de fonte" e gerar sprint.md a partir do backlog)
- `.claude/commands/sync-skills.md` — utilitário existente para sincronizar skills entre worktrees
- `.claude/commands/validate.md` — não muda; alinha com plan.md (fluxo não afetado)
- `.claude/commands/ship-feature.md` — não muda; apenas faz PR
- `.claude/commands/project-compass.md` — precisará ler backlog.json além de sprint.md para estado completo
- `.claude/commands/improve-skill.md` — ferramenta para iterar skills; usaremos para iterar start-feature após o redesign

### Skills globais (`~/.claude/commands/`)
- `~/.claude/commands/plan-roadmap.md` — gera `roadmap.md`; torna-se "fonte de milestones para backlog.json" — pode ser atualizada para gravar direto no backlog.json ao invés de só no md
- `~/.claude/commands/create-skill.md` — será usada para criar `/debug` (não criar na mão)

### Sem backlog.json ainda
Não existe nenhum `backlog.json` no projeto. Será criado do zero nesta feature.

### Sem skill `/debug` ainda
`.claude/commands/debug.md` não existe. Será criada via `/create-skill`.

## Padrões identificados

- **Detecção de fase por arquivo**: pattern atual de `start-feature` (descoberta por presença de `discovery.md`, `research.md`, `plan.md`) permanece — apenas a lógica de default flag muda
- **Slugs kebab-case**: todos os nomes de feature e skill seguem kebab-case
- **Worktrees em `.claude/worktrees/<nome>`**: convenção estabelecida, não muda
- **`.claude/feature-plans/<nome>/`**: diretório por feature permanece como mecanismo de state entre sessões
- **Skills são markdown**: sem frontmatter YAML — commands usam a estrutura `# /nome` + seções
- **`/sync-skills`**: mecanismo para propagar skills atualizadas a outros worktrees ativos; deve ser rodado após esta feature ser mergeada

## Dependências externas

Nenhuma lib ou secret novo necessário. Apenas:
- `jq` — para ler/escrever backlog.json nos scripts inline das skills (já presente no macOS via brew, ou via `command -v jq` check)
- `gh` CLI — já em uso no projeto para PR operations em `/close-feature`

## Hot files que serão tocados

- `.claude/commands/start-feature.md` — redesign principal ⚠️ stale worktrees em branches não-mergeadas tocam este arquivo — verificar antes de criar worktree
- `.claude/commands/close-feature.md` — update para backlog.json ⚠️ idem
- `.claude/commands/start-milestone.md` — update menor para ler backlog.json ⚠️ idem
- `.claude/commands/project-compass.md` — update para incluir backlog.json no estado ⚠️ idem
- `CLAUDE.md` — ⚠️ hot file por definição; se houver nova armadilha, adicionar aqui

### Situação dos stale worktrees
O conflict checker identificou 6+ worktrees ativas que tocam `.claude/commands/`. Muitas parecem
ser de features já mergeadas (launch-distribution, backlog) mas com worktrees não removidas.
**Ação necessária antes de Fase C:** rodar `git worktree list` e verificar quais worktrees são
realmente stale (PR merged) vs. ativas. Rodar `/close-feature` nas stale antes de criar
worktree para skill-workflow-ux.

## Schema proposto: backlog.json

Baseado na análise Shape Up + estabilidade de schema. Campos mínimos e estáveis desde v1:

```json
{
  "schemaVersion": "1-0-0",
  "updatedAt": "ISO-8601",
  "project": {
    "name": "claude-terminal",
    "path": "/Users/rmolines/git/claude-terminal"
  },
  "milestones": [
    {
      "id": "m1",
      "name": "Nome descritivo",
      "status": "pending|active|completed|deferred",
      "doneAt": null
    }
  ],
  "pitches": [
    {
      "id": "pitch-<slug>",
      "title": "Título",
      "problem": "Descrição do problema",
      "status": "awaiting-bet|rejected|won",
      "createdAt": "ISO-8601",
      "notes": ""
    }
  ],
  "features": [
    {
      "id": "<slug>",
      "title": "Título",
      "status": "pending|in-progress|blocked|done",
      "milestone": "m1",
      "effort": "low|medium|high",
      "dependencies": [],
      "branch": null,
      "prNumber": null,
      "startedAt": null,
      "completedAt": null,
      "createdAt": "ISO-8601"
    }
  ]
}
```

**Regras de estabilidade:**
- Nunca remover/renomear campo — apenas deprecar e adicionar novo
- `schemaVersion` seguindo SchemaVer (MODEL-REVISION-ADDITION)
- Skills validam schemaVersion ao ler e recusam escrever se version > "1-0-0"

## Riscos e restrições

1. **Breaking change de UX**: inverter o default do `start-feature` (`--fast` vira padrão) quebra o workflow mental de quem já usa. Documentar claramente no CLAUDE.md e no próprio skill.

2. **Skills globais vs. de projeto**: `start-feature` existe em `~/.claude/commands/` (global) e `.claude/commands/` (projeto). Mudanças no projeto não sincronizam automaticamente para o global. Após o redesign, rodar `/sync-skills` E atualizar o arquivo global manualmente se aplicável.

3. **Stale worktrees com `.claude/commands/` modificado**: se uma worktree stale tem um `start-feature.md` diferente do main, um `git worktree remove --force` vai descartar as mudanças dela. Verificar antes.

4. **backlog.json schema freeze**: a UI futura (feature `backlog-ui`) vai depender do schema. Uma vez criado e commitado, mudanças de campo são breaking. O schema acima foi desenhado para ser estável.

5. **`jq` como dependência**: skills precisam de `jq` para manipular backlog.json. Adicionar check no início dos snippets que usam jq: `command -v jq >/dev/null || { echo "jq required: brew install jq"; exit 1; }`.

6. **`--discover` vira "pitch mode"**: atualmente `--discover` lança discovery + research e para. No novo design isso deve continuar igual — apenas o default muda para fast.

## Fontes consultadas

- Shape Up (37signals): `https://basecamp.com/shapeup/`
- Snowplow SchemaVer: `https://docs.snowplow.io/docs/pipeline-components-and-applications/iglu/common-architecture/schemaver/`
- Claude Code Skills docs: `https://code.claude.com/docs/en/skills`

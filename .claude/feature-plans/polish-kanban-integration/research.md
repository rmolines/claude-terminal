# Research: polish-kanban-integration

## Descricao da feature

Registrar polish sprints no `backlog.json` (`chores[]`) para que `/project-compass` exiba
historico de chores e o projeto tenha visibilidade completa de atividade de melhoria continua.
Tres mudancas cirurgicas: `polish.md` (escrita + close), `project-compass.md` (leitura), `backlog.json` (schema).

## Arquivos existentes relevantes

### `.claude/commands/polish.md` — estado atual

Passos: 1 (lista) → 2 (branch) → 3 (loop: anunciar + implementar + micro-commit) → 4 (resumo)
→ 5 (build) → 6 (PR via GitHub MCP).

O que **falta**:

- **Passo 6**: apos criar o PR, capturar `prNumber` e `prUrl` do response do MCP e escrever
  registro em `backlog.json chores[]`.
- **Passo 5**: so roda `swift build`. Nao tem `swift test`, sem `RenderPreview` para itens de
  UI, sem checklist manual.
- **Flag `--close`**: nao existe. Precisa ser detectada no topo do skill para chamar o fluxo
  de fechamento (update `status: "merged"` + delete branch).

### `.claude/commands/project-compass.md` — estado atual

Phase 1c le `backlog.json` mas extrai apenas `milestones`, `features` e `pitches`.
Phase 3 exibe secoes: Onde estamos, O que foi construido, O que fazer agora, Pitches, Proxima acao.

O que **falta**:

- Phase 1c: extrair tambem `chores[]` do JSON.
- Phase 3: nova secao "Chores recentes" apos Pitches.

### `.claude/backlog.json` — estrutura atual

Top-level keys: `project`, `updatedAt`, `milestones[]`, `features[]`, `pitches[]`, `icebox[]`.

O que **falta**: `"chores": []` como array top-level. Adicao aditiva — sem migration.

### `.claude/commands/close-feature.md` — padrao REPO_ROOT + jq (referencia)

```bash
REPO_ROOT=$(git worktree list | head -1 | awk '{print $1}')
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  echo "ERRO: nao foi possivel determinar REPO_ROOT. Abortando."
  exit 1
fi
```

```bash
BACKLOG="$REPO_ROOT/.claude/backlog.json"
if [ -f "$BACKLOG" ] && command -v jq >/dev/null; then
  jq '...' "$BACKLOG" > "$BACKLOG.tmp" && mv "$BACKLOG.tmp" "$BACKLOG"
fi
```

Este padrao e o contrato do projeto para qualquer write em backlog.json. Espelhar exatamente.

## Padroes identificados

### jq null-safe append em `chores[]`

```bash
REPO_ROOT=$(git worktree list | head -1 | awk '{print $1}')
BACKLOG="$REPO_ROOT/.claude/backlog.json"
if [ -f "$BACKLOG" ] && command -v jq >/dev/null; then
  ENTRY=$(jq -n \
    --arg id      "polish-$DATE" \
    --arg type    "polish" \
    --arg date    "$DATE" \
    --arg branch  "$BRANCH" \
    --argjson pr  "$PR_NUMBER" \
    --arg url     "$PR_URL" \
    --arg status  "open" \
    --argjson items   "$ITEMS_JSON" \
    --argjson skipped "$SKIPPED_JSON" \
    '{id:$id, type:$type, date:$date, branch:$branch, prNumber:$pr, prUrl:$url,
      status:$status, items:$items, skipped:$skipped}')
  jq --argjson entry "$ENTRY" \
     '. + {chores: ((.chores // []) + [$entry])}' \
     "$BACKLOG" > "$BACKLOG.tmp" && mv "$BACKLOG.tmp" "$BACKLOG"
fi
```

`(.chores // [])` garante null-safety mesmo quando a key ainda nao existe.

### jq update de status para `--close`

```bash
jq --arg branch "$BRANCH" \
   '.chores |= map(if .branch == $branch then . + {status: "merged"} else . end)' \
   "$BACKLOG" > "$BACKLOG.tmp" && mv "$BACKLOG.tmp" "$BACKLOG"
```

Match por `branch` (nao `id`) — mais seguro: id e derivado da data e pode colidir se dois
polishes sao abertos no mesmo dia; branch e unico.

### Capturar PR number/url do response do MCP

`mcp__plugin_github_github__create_pull_request` retorna um objeto com `number` e `html_url`.
Capturar imediatamente apos a chamada e usar nas variaveis `PR_NUMBER` e `PR_URL`.

### Items/skipped como JSON arrays

No Passo 4 (resumo), o skill ja tem a lista de itens concluidos e pulados.
Serializar antes do jq write:

```bash
# Construir arrays JSON a partir das listas do Passo 4
ITEMS_JSON='["Fix X","Refactor Y"]'      # itens concluidos
SKIPPED_JSON='["Item Z — motivo"]'       # itens pulados
```

Na pratica, o skill constroi essas strings em markdown durante o Passo 4 —
o agente deve montar os JSON arrays a partir dos mesmos dados.

### Deteccao de flag `--close` no topo do skill

Igual ao padrao de `start-feature.md` — verificar `$ARGUMENTS` antes de qualquer leitura:

```bash
if [[ "$ARGUMENTS" == --close* ]]; then
  # fluxo de close
else
  # fluxo normal
fi
```

### Fluxo `--close`

1. Detectar branch atual: `BRANCH=$(git branch --show-current)`
2. Verificar se e uma branch de polish: `[[ "$BRANCH" == chore/polish-* ]]`
3. REPO_ROOT pattern (identico ao close-feature.md)
4. Update `status: "merged"` via jq (match por `branch`)
5. Deletar branch local: `git branch -D "$BRANCH"`
6. Deletar branch remota: `gh api -X DELETE "repos/$OWNER/$REPO/git/refs/heads/$BRANCH"`

Nao usa worktrees — polish cria branches normais com `git checkout -b`.

### project-compass — secao Chores

Phase 1c (leitura do backlog.json) ja extrai JSON completo.
Adicionar extracao de `chores[]` na sintese da Phase 1c.

Phase 3 — nova secao (inserir apos Pitches, antes de "Proxima acao"):

```text
### Chores recentes (se houver registros em chores[])

| Data | PR | Itens | Status |
|------|-----|-------|--------|
| YYYY-MM-DD | #N | K itens | merged / open |

(Omitir esta secao se `chores[]` estiver vazio ou ausente)
```

## Dependencias externas

- `jq` (brew install jq) — ja guardado por `command -v jq` com skip silencioso
- `gh` CLI — ja usado em close-feature.md e project-compass.md (Fase 1d)
- Xcode MCP (`RenderPreview`) — so para polish sprints com itens de UI; degradar graciosamente se nao disponivel

## Hot files que serao tocados

Nenhum dos 3 arquivos e hot file do CLAUDE.md (que lista apenas Swift source, CI, entitlements e Package.swift).
Sem conflitos potenciais.

- `.claude/commands/polish.md` — adicionar Passo 5b (tests + RenderPreview), Passo 6b (chores write), fase `--close`
- `.claude/commands/project-compass.md` — adicionar extracao de `chores[]` em 1c; secao "Chores" em 3
- `.claude/backlog.json` — adicionar `"chores": []` top-level

## Riscos e restricoes

| Risco | Mitigacao |
|---|---|
| Worktree path — escrita relativa vai para branch errada | `REPO_ROOT=$(git worktree list \| head -1 \| awk '{print $1}')` antes de qualquer write (padrao close-feature.md) |
| `chores` key ausente no backlog existente | `(.chores // [])` — null-safe; funciona mesmo sem a key |
| `jq` nao disponivel | `command -v jq >/dev/null \|\| { echo "jq nao encontrado — pular..."; }` com skip silencioso |
| `RenderPreview` sem Xcode aberto | Avisar no test step: "MCP nao disponivel — usar checklist manual para itens de UI" |
| PR number nao capturado do MCP | Capturar `number` + `html_url` do response de `create_pull_request` imediatamente apos a chamada |
| `--close` em branch nao-polish | Guard: `[[ "$BRANCH" == chore/polish-* ]] \|\| { echo "Branch atual nao e de polish"; exit 1; }` |
| Dois polishes no mesmo dia — id collision | `id: "polish-$DATE-$BRANCH"` onde BRANCH e unico (tem hora se necessario) — ou simplesmente usar branch como chave unica |
| markdownlint — code blocks sem language tag | Sempre usar backtick fence com linguagem (bash, json, text) — regra MD040 do projeto |

## Fontes consultadas

Leitura direta dos arquivos do projeto — sem web search necessario (feature nao usa libs externas).
Padroes derivados de: `close-feature.md` (REPO_ROOT + jq), `backlog.json` (schema existente),
`polish.md` e `project-compass.md` (estrutura atual).

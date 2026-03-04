# Plan: skill-workflow-ux

## Problema

O sistema de skills atual tem custo de processo desconectado do tamanho da mudança.
Features pequenas pagam o mesmo overhead de pesquisa e planejamento que features grandes.
O `--fast` existe mas é flag escondida — o dev tem que lembrar de usá-lo. Não há fonte
de verdade centralizada para features/pitches além de arquivos markdown. Não há caminho
para investigação sem commit.

**Critérios de sucesso:**
- `/start-feature slug` (sem flag) vai direto à execução sem research/plan
- `/start-feature --discover slug` gera pitch (discovery.md + research.md) e para
- `/start-feature slug` após `--discover` detecta research.md e começa no planejamento
- `backlog.json` atualizado automaticamente ao fechar feature
- `/debug` investiga erro com MCP e entrega relatório sem commitar nada

## Arquivos a modificar

- `.claude/commands/start-feature.md` — redesign principal: inverter default, novo flag `--discover` como pitch mode, `--deep` para full workflow
- `.claude/commands/close-feature.md` — adicionar auto-detecção de PR merged + update backlog.json
- `.claude/commands/project-compass.md` — ler backlog.json além de sprint.md como fonte de estado
- `.claude/commands/start-milestone.md` — gravar em backlog.json ao criar milestones/features

## Arquivos a criar

- `.claude/backlog.json` — fonte de verdade: milestones + pitches + features com status
- `.claude/commands/debug.md` — nova skill de investigação sem commits
- `.claude/rules/thinking-style.md` — princípio de raciocínio de base zero para skills

## Passos de execução

### Passo 1 — Criar `backlog.json`

1. Ler `.claude/feature-plans/claude-terminal/roadmap.md` para mapear milestones M1-M3
2. Ler `git log --oneline -20` para detectar PRs e estado atual (incluindo M4 se existir)
3. Criar `.claude/backlog.json` com schema da research.md, com as seguintes decisões de campo:

**`pitches` — campo `appetite: "fast|deep|discover"`:**
Representa quanto tempo o dev está disposto a gastar ANTES de apostar. Mapeia diretamente
para o flag do `/start-feature` que será usado ao fazer o bet:
- `"fast"` → `/start-feature <slug>` (1 sessão, execução direta, sem research)
- `"deep"` → `/start-feature --deep <slug>` (2-3 sessões, com research + plan)
- `"discover"` → `/start-feature --discover <slug>` (sessões abertas, ainda explorando)

**`features` — campo `path: "fast|deep|discover"` (não `appetite`):**
Descreve o caminho de execução que foi tomado após o bet. `appetite` não se aplica a
features ativas — o tempo está sendo gasto, não estimado.

**Schema completo dos arrays relevantes:**
```json
"pitches": [
  {
    "id": "pitch-<slug>",
    "title": "Título",
    "problem": "Descrição do problema",
    "appetite": "fast|deep|discover",
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
    "path": "fast|deep|discover",
    "dependencies": [],
    "branch": null,
    "prNumber": null,
    "startedAt": null,
    "completedAt": null,
    "createdAt": "ISO-8601"
  }
]
```

4. Popular com M1 (completed), M2 (completed), M3 (parcialmente completed), feature `skill-workflow-ux` com `status: "in-progress"`, `path: "discover"` (veio de um --discover anterior)
5. Validar JSON com `python3 -m json.tool .claude/backlog.json > /dev/null`

### Passo 2 — Redesenhar `start-feature.md`

Reescrever `.claude/commands/start-feature.md` com nova lógica de detecção de fase:

**Nova hierarquia de detecção (em ordem):**

1. Check arquivos em `.claude/feature-plans/<nome>/` (continuação de sessão anterior):
   - `plan.md` existe → Fase C (execução)
   - `research.md` existe (sem plan.md) → Fase B (planejamento)
   - `discovery.md` existe (sem research.md) → Fase A (pesquisa)

2. Se nenhum arquivo existe:
   - `--discover` flag → Fase 0 (pitch mode: discovery + research, para sem criar worktree)
   - `--deep` flag → Fase A (full workflow: research + plan + execução)
   - Sem flag (default) → Fase C fast (1 pergunta + mini plan + execução)

3. Se sem nome e sem flag:
   - Ler `.claude/backlog.json` para próxima feature `status=pending`
   - Se não existir backlog.json: ler sprint.md (fallback)
   - Apresentar sugestão e aguardar confirmação

**Nova Fase C fast (default sem pesquisa):**
1. Claude lê CLAUDE.md + arquivos relevantes (sem subagentes — leitura direta)
2. Faz 1-2 perguntas: "o que deve fazer?" + "quais arquivos serão tocados?"
3. Gera mini plan.md (problema + passos + rollback mínimo)
4. Mostra ao usuário para confirmação rápida
5. Cria worktree e executa

**Mudanças de flags:**
- `--discover` = Fase 0 (pitch: discovery.md + research.md, PARA — não cria worktree)
- `--deep` = Fase A + B + C (full workflow com pesquisa, old default)
- `--fast` = DEPRECIADO (behavior agora é o default); manter como alias silencioso

**Integração backlog.json:**
- No início: verificar se `command -v jq` disponível para features que usam backlog
- Ao iniciar Fase C: se backlog.json existir, atualizar feature para `status=in-progress`, `startedAt=ISO`, `branch=feature/<nome>`
- Adicionar check de jq antes de qualquer operação de backlog

**Usar 4 backticks** para outer fences quando conteúdo interno tem ` ``` ` (LEARNINGS markdownlint)

### Passo 3 — Atualizar `close-feature.md`

Adicionar **após o Passo 1 atual** (leitura do plan.md), um novo passo "0.5 — Detectar PR":

```bash
BRANCH=$(git branch --show-current 2>/dev/null || git -C "$WORKTREE_PATH" branch --show-current)
PR_DATA=$(gh pr list --head "$BRANCH" --state merged --json number,mergedAt --limit 1 2>/dev/null || echo "[]")
PR_NUMBER=$(echo "$PR_DATA" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data[0]['number'] if data else '')" 2>/dev/null)
```

Se PR_NUMBER encontrado: usar automaticamente no CHANGELOG e no update de backlog.json.
Se não encontrado: perguntar ao usuário ou pular update de backlog.json.

Adicionar novo **Passo 1f — Atualizar backlog.json** (após LEARNINGS.md):

```bash
command -v jq >/dev/null || { echo "jq required: brew install jq"; exit 1; }
BACKLOG=".claude/backlog.json"
if [ -f "$BACKLOG" ]; then
  TODAY=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq --arg id "<nome>" \
     --arg pr "<pr_number>" \
     --arg date "$TODAY" \
     '(.features[] | select(.id == $id)) |= . + {status: "done", completedAt: $date, prNumber: ($pr | tonumber? // null)}' \
     "$BACKLOG" > "$BACKLOG.tmp" && mv "$BACKLOG.tmp" "$BACKLOG"
  echo "backlog.json atualizado: <nome> → done"
fi
```

### Passo 4 — Atualizar `project-compass.md`

Na Fase 1 (Carregar contexto em paralelo), adicionar **1c. Backlog JSON** (antes da seção de PRs merged):

```bash
cat .claude/backlog.json 2>/dev/null || echo "(sem backlog.json)"
```

Extrair: milestones com status, features por milestone com status, pitches pendentes.

Na Fase 2 (Cruzar dados), adicionar lógica:
- Se backlog.json existe: usar como fonte primária de status das features
- sprint.md como fonte de detalhes de decomposição (complementar)
- features com `status=in-progress` no backlog → "em andamento"
- features com `status=done` → "done"

Na Fase 3 (Gerar relatório), adicionar seção "Pitches" se backlog.json tiver items:

```markdown
### 💡 Pitches (ideias sem commitment)

| Pitch | Problema | Status |
|-------|---------|--------|
| <título> | <problema curto> | awaiting-bet |
```

### Passo 5 — Atualizar `start-milestone.md`

Na Fase 3 (após criar sprint.md), adicionar passo: **atualizar backlog.json**

Se `.claude/backlog.json` existe:
- Adicionar milestone ao array `milestones` se não existir (id, name, status=active)
- Adicionar cada feature confirmada ao array `features` (id=slug, title, status=pending, milestone=id, effort)
- Validar com `python3 -m json.tool .claude/backlog.json > /dev/null` após update

Se não existe: não criar (responsabilidade da inicialização manual ou `/start-project`).

Na Fase 0 (Detecção), adicionar: se `roadmap.md` não existir mas `.claude/backlog.json` existir,
ler backlog.json para listar milestones com status=pending ou active.

### Passo 6 — Criar `.claude/rules/thinking-style.md`

Criar com o seguinte conteúdo:

```markdown
# Rule: Thinking Style

## Raciocínio de base zero

Antes de responder a uma pergunta de design ou propor uma solução, verifique se a
pergunta tem uma resposta óbvia por analogia com outro contexto. Se tiver, pause.

**Perguntas a fazer antes de responder:**
- O conceito que estamos importando (ex: Shape Up, Clean Architecture, padrão X) se
  aplica ao contexto real, ou estamos só fazendo mapeamento automático?
- A resposta óbvia resolve o problema do *usuário* ou resolve o problema *como foi formulado*?
- Se eu discordasse, o que eu diria?

**Quando usar:** qualquer momento em que a resposta for imediata demais. A velocidade
da resposta é sinal de que a premissa não foi questionada.

**Anti-padrão:** concordar com o usuário e estender a ideia dele sem checar se a direção
está correta. Preferir uma resposta mais curta e honesta a uma longa e validadora.

## Aplicação em skills

Skills que envolvem decisões de design (discovery, planejamento, debug) devem incluir
um passo de "questionar a premissa" antes de propor a solução:

- `/start-feature --discover`: antes de propor escopo, questionar se o problema está
  formulado corretamente
- `/debug`: antes de hipotetisar a causa, listar o que *não* pode ser a causa
- Qualquer skill de planejamento: se a abordagem óbvia parece clara demais, investigar
  se há restrições não declaradas
```

### Passo 7 — Criar `debug.md`

Criar `.claude/commands/debug.md` com:

**Objetivo:** Investigar um erro ou comportamento inesperado usando Xcode MCP + leitura de arquivos.
Nunca modifica arquivos, nunca commita, nunca faz push.

**Fluxo:**
1. Receber descrição do problema (argumento `$ARGUMENTS` ou perguntar)
2. Rodar em paralelo:
   - `XcodeListNavigatorIssues` — erros e warnings no Issue Navigator
   - `BuildProject` — tentar build e capturar erros estruturados
   - Leitura dos arquivos relevantes mencionados na descrição
3. Se erros de build: `GetBuildLog` para detalhes
4. Para cada arquivo com erro: `XcodeRefreshCodeIssuesInFile` + ler o arquivo
5. Gerar relatório:
   - Causa raiz hipotética
   - Arquivos afetados com número de linha
   - Fix sugerido (texto, não código — deixar para o usuário aplicar ou chamar `/fix`)
   - Se Swift: buscar em CLAUDE.md e LEARNINGS.md se já é armadilha conhecida
6. Encerrar sem criar nenhum arquivo

**Regras:**
- NUNCA usar Write, Edit, Bash com modificação de arquivo
- NUNCA usar git add, git commit, git push
- Se o problema for resolvível trivialmente: descrever o fix mas não aplicar
- Para aplicar o fix: sugerir `/fix <descrição>`

## Checklist de infraestrutura

- [x] Novo Secret: não
- [x] Script de setup: não
- [x] Dockerfile / imagem: não muda
- [x] Config principal do projeto: CLAUDE.md pode receber nota sobre `--fast` deprecado
- [x] CI/CD: não muda
- [x] Novas dependências: `jq` (já no macOS via brew — adicionar check `command -v jq` antes de uso)

## Rollback

Skills são markdown — rollback é simples:
```bash
git checkout main -- .claude/commands/start-feature.md
git checkout main -- .claude/commands/close-feature.md
git checkout main -- .claude/commands/project-compass.md
git checkout main -- .claude/commands/start-milestone.md
rm .claude/commands/debug.md
rm .claude/backlog.json
```

## Learnings aplicados

- **4 backticks para fences aninhadas**: skill files frequentemente têm ` ``` ` dentro de ` ``` `. Usar outer fence com 4 backticks quando necessário.
- **`jq` como dependência**: sempre checar `command -v jq` antes de qualquer snippet que usa jq; falha clara com mensagem de install.
- **Worktrees e CWD**: durante Fase C fast, verificar `git branch --show-current` antes de criar arquivos de código (deve ser `feature/<nome>`).
- **Breaking change de UX**: inverter o default do start-feature quebra workflow mental — documentar claramente no início do skill e no CLAUDE.md.

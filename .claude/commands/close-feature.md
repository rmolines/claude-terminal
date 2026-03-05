# /close-feature

Você é um assistente de desenvolvimento executando o skill `/close-feature`.

Este skill fecha uma feature após ela já ter sido validada em produção via `/ship-feature`.
Cuida apenas de **documentação e cleanup** — não faz commit, push, PR nem deploy.

Se a feature ainda não foi validada em produção, rode `/ship-feature` primeiro.

---

## Passos

### 0. Ler o plano da feature (se existir)

Perguntar o nome da feature se não foi informado.

Verificar se `.claude/feature-plans/<nome>/plan.md` existe.
Se sim: ler integralmente para entender o que foi feito (contexto para a documentação).

### 0.5 — Detectar PR mergeado

```bash
BRANCH=$(git branch --show-current 2>/dev/null || git -C "$WORKTREE_PATH" branch --show-current)
PR_DATA=$(gh pr list --head "$BRANCH" --state merged --json number,mergedAt --limit 1 2>/dev/null || echo "[]")
PR_NUMBER=$(echo "$PR_DATA" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data[0]['number'] if data else '')" 2>/dev/null)
```

Se `PR_NUMBER` encontrado: usar nos passos 1b (CHANGELOG) e 1g (backlog.json).
Se não encontrado: perguntar ao usuário o número ou pular o update de backlog.json.

### 0.6 — Garantir branch main para commits de docs

```bash
BRANCH=$(git branch --show-current 2>/dev/null)
if [ "$BRANCH" != "main" ]; then
  echo "Branch atual: $BRANCH — mudando para main antes de commitar docs"
  git checkout main
  git pull --rebase origin main
fi
```

Sem essa etapa, docs commitados na branch de feature/chore ficam fora do main.

### 0.7 — Ler todos os arquivos de doc em paralelo

Ler simultaneamente (um único batch) antes de iniciar qualquer edição:

- `CHANGELOG.md`
- `HANDOVER.md`
- `LEARNINGS.md`
- `CLAUDE.md`

Garantir que todos foram lidos antes de iniciar qualquer Edit/Update.
Evita o erro "File must be read first" durante as edições sequenciais.
Se algum arquivo não existir: ignorar (será criado no passo correspondente).

### 1. Atualizar documentação

Execute cada item em sequência:

#### 1a. HANDOVER.md

Gerar entrada com:
- Data atual (`YYYY-MM-DD`)
- O que foi feito, decisões tomadas, armadilhas encontradas, próximos passos, arquivos-chave

Fazer append em `HANDOVER.md` na raiz do projeto (criar se não existir).

#### 1b. CHANGELOG.md — prepend no topo

Gerar entrada no `CHANGELOG.md` (raiz do repo). Criar o arquivo se não existir.

**Coletar dados necessários:**
- Ler `.claude/feature-plans/<nome>/plan.md` (se existir) para contexto
- Número do PR mergeado: `git log --oneline -5` ou perguntar ao usuário se não estiver claro
- URL do repo: `git remote get-url origin` (converter SSH → HTTPS se necessário)
- Tipo: `feat` / `fix` / `improvement` / `breaking` (inferir do contexto)

**Formato para feature (feat/improvement/breaking):**

```markdown
## [<type>] <Título conciso> — YYYY-MM-DD

**Tipo:** <type>
**Tags:** <tag1>, <tag2>
**PR:** [#N](<repo-url>/pull/N) · **Complexidade:** <simples|média|alta>

### O que mudou
<1-2 frases em linguagem simples: o que o usuário/dev vê de diferente>

### Detalhes técnicos
- <bullet com arquivo ou mudança principal>
- <bullet 2>

### Impacto
- **Breaking:** <Não | Sim — descrição>

### Arquivos-chave
- `path/to/file` — descrição

---
```

**Formato para fix:**

```markdown
## [fix] <Título conciso> — YYYY-MM-DD

**Tipo:** fix
**Tags:** <tag1>, <tag2>
**PR:** [#N](<repo-url>/pull/N) · **Complexidade:** simples

### Problema
<1-2 frases descrevendo o bug>

### Fix aplicado
<o que foi feito para corrigir>

### Arquivos-chave
- `path/to/file` — descrição

---
```

**Inserir:** logo após a linha `# Changelog` (antes da primeira entrada `##`).
Usar Edit tool com `old_string` = primeira linha após o cabeçalho e `new_string` = nova entrada + essa mesma linha.

#### 1c. MEMORY.md coordinator — commit direto em main (se existir)

Verificar se `.claude/agent-memory/coordinator/MEMORY.md` existe.

**Se existir:**

```bash
REPO_ROOT=$(git worktree list | head -1 | awk '{print $1}')
MEMORY_FILE="$REPO_ROOT/.claude/agent-memory/coordinator/MEMORY.md"

git -C "$REPO_ROOT" pull --rebase origin main
```

Editar MEMORY_FILE com Edit tool (path absoluto):
- Remover a linha da tabela `## Worktrees ativas` onde Worktree = `<nome>`
- Remover TODAS as linhas da tabela `## Hot file claims (ativo)` onde Worktree = `<nome>`

```bash
git -C "$REPO_ROOT" add .claude/agent-memory/coordinator/MEMORY.md
git -C "$REPO_ROOT" commit -m "chore(coordinator): unregister worktree <nome>"
git -C "$REPO_ROOT" push origin main
```

**Se não existir:** pular este passo.

#### 1d. LEARNINGS.md (se houver novidades)

Verificar se `{{LEARNINGS_PATH}}` existe no projeto.

**Você** decide se algo desta sessão vale registrar — não pergunte ao usuário.
Critério: algo não documentado que causou surpresa, ou que seria útil em situações futuras.

Se sim: propor o aprendizado ao usuário e, com aprovação, adicionar:
```markdown
## <data> — <título curto>
<aprendizado>
```

Se não houver nada novo: pular sem perguntar.

#### 1e. CLAUDE.md — armadilhas (se houver novidades)

**Você** decide se houve armadilha nova — não pergunte ao usuário.
Critério: problema não-óbvio que outro agente cometeria no mesmo contexto.

Se sim: propor ao usuário e, com aprovação, adicionar à tabela de armadilhas no CLAUDE.md.
Se não houver nada novo: pular sem perguntar.

#### 1f. LEARNINGS.md — fricção de processo (se houve)

**Você** decide se algo deu errado durante a execução de `/ship-feature` ou `/close-feature`
nesta sessão — não pergunte ao usuário.

Critério: erros ou fricção causados pela skill, não pela feature em si.
Exemplos: commit na branch errada, "file must be read first", polling de CI que não encontrou
o run, worktree não detectada, merge em branch errada, etc.

Se sim: adicionar seção ao `LEARNINGS.md`:

```markdown
## <data> — [processo] <título curto>
<descrição do que deu errado, quando, e o fix sugerido na skill>
```

Se não houve fricção de processo: pular sem mensagem.

#### 1g. backlog.json (se existir)

```bash
command -v jq >/dev/null || { echo "jq não encontrado — pular update de backlog.json (brew install jq para habilitar)"; }
BACKLOG=".claude/backlog.json"
if [ -f "$BACKLOG" ] && command -v jq >/dev/null; then
  TODAY=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq --arg id "<nome>" \
     --arg pr "<pr_number>" \
     --arg date "$TODAY" \
     '(.features[] | select(.id == $id)) |= . + {status: "done", completedAt: $date, prNumber: ($pr | tonumber? // null)}' \
     "$BACKLOG" > "$BACKLOG.tmp" && mv "$BACKLOG.tmp" "$BACKLOG"
  echo "backlog.json atualizado: <nome> → done"
fi
```

Substituir `<nome>` pelo slug da feature e `<pr_number>` pelo PR detectado no Passo 0.5 (ou `""` se não encontrado).

#### 1h. Propagação ao kickstart (se houver skills novos/modificados)

Verificar se algum arquivo em `.claude/commands/` foi criado ou modificado nesta feature:

```bash
git diff origin/main...HEAD --name-only | grep "^\.claude/commands/"
```

Se **nenhum skill foi tocado**: pular sem mensagem.

Se **há skills novos ou modificados**, avaliar cada um:

**Você** decide se o skill tem lógica genérica o suficiente para outros projetos — não pergunte ao usuário.
Critério: o skill resolve um problema que qualquer projeto com esse workflow teria, e a lógica
pode ser expressa com `{{PLACEHOLDERS}}` sem perder utilidade.

Exemplos que **devem** propagar: skills de revisão, checkpoints de qualidade, workflows de design.
Exemplos que **não devem**: skills com paths, comandos ou contexto exclusivos deste projeto.

Para cada skill candidato, apresentar:

```text
📤 "<nome>" foi criado/modificado nesta feature.
   Lógica parece genérica o suficiente para o kickstart.
   Confirmar propagação? (sim = crio versão template e faço PR no kickstart; não = fica só aqui)
```

Com confirmação, criar a versão template:

1. Ler o skill atual e identificar elementos projeto-específicos
2. Substituir por `{{PLACEHOLDER}}` — ex: paths hardcoded, nomes de ferramentas, constraints específicas
3. Adicionar seções `## Quando NÃO usar` e `## Testes` se ausentes (padrão kickstart)
4. Escrever em `/Users/rmolines/git/claude-kickstart/.claude/commands/<nome>.md`
5. Fazer commit e PR no kickstart:

```bash
KICKSTART=/Users/rmolines/git/claude-kickstart
git -C "$KICKSTART" add .claude/commands/<nome>.md
git -C "$KICKSTART" commit -m "feat(skills): add /<nome> — propagated from <projeto>"
# Usar gh api diretamente (gh pr create pode detectar repo errado em worktrees):
BRANCH=$(git -C "$KICKSTART" branch --show-current)
git -C "$KICKSTART" push origin "$BRANCH"
gh api repos/rmolines/claude-kickstart/pulls \
  --method POST \
  -f title="feat(skills): add /<nome>" \
  -f head="$BRANCH" \
  -f base="main" \
  -f body="Propagado de <projeto> após uso real na feature <nome-feature>."
```

Exibir URL do PR e aguardar confirmação de merge antes de continuar.

Após merge confirmado, sincronizar a versão genérica de volta ao projeto:

```bash
make sync-skills
```

Se `make sync-skills` não existir: avisar e sugerir verificar o Makefile.

### 2. Remover worktree e branch local

```bash
REPO_ROOT=$(git worktree list | head -1 | awk '{print $1}')
WORKTREE_PATH="$REPO_ROOT/.claude/worktrees/<nome>"
```

Verificar se a worktree existe:
```bash
git -C "$REPO_ROOT" worktree list | grep "<nome>"
```

- Se existir e o agente atual estiver **dentro** dela: avisar que precisa sair primeiro (a worktree não pode remover a si mesma)
- Se existir e o agente estiver **fora** dela:
  ```bash
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
  git -C "$REPO_ROOT" worktree prune
  git -C "$REPO_ROOT" branch -D worktree-<nome> 2>/dev/null || true
  # Limpar remote branch se ship-feature não deletou (falha silenciosa em worktree)
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
  gh api -X DELETE "repos/$REPO/git/refs/heads/worktree-<nome>" 2>/dev/null || true
  ```
- Se não existir no `git worktree list` mas o diretório ainda estiver em disco:
  ```bash
  rm -rf "$WORKTREE_PATH"
  ```
- Se não existir em nenhum dos dois: pular sem mensagem

### 2.5 — Limpar TodoWrite tasks abertas

Verificar se há tasks abertas relacionadas à feature via TodoRead.
Para cada task com status `in_progress` ou `pending` que mencione o nome da feature
ou seja claramente relacionada: marcar como `done`.

Se não houver tasks abertas relacionadas: pular sem mensagem.

### 3. Limpar feature-plans

- Verificar se existe `.claude/feature-plans/<nome>/`
- **Sempre arquivar automaticamente** → mover para `.claude/feature-plans/archived/<nome>/` sem perguntar

### 4. Resumo final

```text
✅ Feature encerrada!

Documentação:
- HANDOVER.md ✅
- CHANGELOG.md ✅
- MEMORY.md coordinator <✅ ou ⏭️ sem coordinator>
- LEARNINGS.md <✅ ou ⏭️ pulado>
- LEARNINGS.md fricção de processo <✅ ou ⏭️ sem fricção>
- CLAUDE.md armadilhas <✅ ou ⏭️ pulado>
- Kickstart propagation <✅ PR aberto | ⏭️ sem skills candidatos | ⏭️ não confirmado pelo dev>

Worktree: <removida | já não existia | aguardando saída manual>
feature-plans: arquivado
Tasks abertas: <limpas | nenhuma encontrada>

Próximos passos:
- <qualquer item pendente, ou "nenhum">
```

---

## Regras

- Nunca fazer commit, push ou PR — responsabilidade do `/ship-feature`
- Se chamado sem feature validada em produção: lembrar de rodar `/ship-feature` primeiro

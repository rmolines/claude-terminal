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

Se `PR_NUMBER` encontrado: usar nos passos 1b (CHANGELOG) e 1f (backlog.json).
Se não encontrado: perguntar ao usuário o número ou pular o update de backlog.json.

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

**Inserir:** logo após a linha `# Changelog` (antes da primeira entrada `## `).
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

#### 1f. backlog.json (se existir)

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

### 3. Limpar feature-plans

- Verificar se existe `.claude/feature-plans/<nome>/`
- **Sempre arquivar automaticamente** → mover para `.claude/feature-plans/archived/<nome>/` sem perguntar

### 4. Resumo final

```
✅ Feature encerrada!

Documentação:
- HANDOVER.md ✅
- CHANGELOG.md ✅
- MEMORY.md coordinator <✅ ou ⏭️ sem coordinator>
- LEARNINGS.md <✅ ou ⏭️ pulado>
- CLAUDE.md armadilhas <✅ ou ⏭️ pulado>

Worktree: <removida | já não existia | aguardando saída manual>
feature-plans: arquivado

Próximos passos:
- <qualquer item pendente, ou "nenhum">
```

---

## Regras

- Nunca fazer commit, push ou PR — responsabilidade do `/ship-feature`
- Se chamado sem feature validada em produção: lembrar de rodar `/ship-feature` primeiro

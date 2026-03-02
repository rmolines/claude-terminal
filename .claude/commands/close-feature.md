# /close-feature

Fecha uma feature após PR merged: cleanup do worktree e atualiza LEARNINGS.md.

O argumento é o nome da feature (mesmo nome usado no `/start-feature`).

---

## Passo 1 — Verificar que PR foi merged

```bash
gh pr view feature/<nome> --json state --jq '.state'
# Deve retornar "MERGED"
```

Se não retornar "MERGED": não continuar. PR ainda está aberto ou foi fechado sem merge.

---

## Passo 1.5 — Marcar feature como done no sprint.md

Após confirmar que PR foi merged, localizar o sprint.md que contém o slug da feature e atualizar o status:

```bash
# Identificar qual sprint.md contém o slug
grep -rl "<slug>" .claude/feature-plans/claude-terminal/M*/sprint.md
```

No arquivo encontrado, atualizar a linha da feature:
- Mudar `pending` → `✅ done`
- Ou marcar o checkbox: `- [ ]` → `- [x]`

Se o sprint.md usa a tabela com coluna `Status`, mudar o valor para `✅ done`.

Fazer commit junto com as atualizações de docs no Passo 4.

---

## Passo 2 — Cleanup do worktree

```bash
FEATURE="<nome>"
WORKTREE_PATH=".claude/worktrees/${FEATURE}"
BRANCH="feature/${FEATURE}"

# Remover worktree
git worktree remove "$WORKTREE_PATH" --force

# Deletar branch local
git branch -d "$BRANCH" 2>/dev/null || true

# Atualizar main
git checkout main
git pull origin main

# Prune worktrees residuais (limpeza preventiva)
git worktree prune
```

---

## Passo 3 — Documentação

### LEARNINGS.md

Adicionar entry com:
- Data e nome da feature
- O que foi aprendido sobre o stack (SwiftData gotchas, IPC, concurrency, etc.)
- O que funcionou bem
- O que teria feito diferente
- Armadilhas novas encontradas (se houver, adicionar também em `CLAUDE.md`)

### CLAUDE.md

Se descobriu novo hot file, nova armadilha, ou a armadilha é diferente do que estava documentado:
atualizar a tabela de armadilhas.

### memory/MEMORY.md

Se o aprendizado é relevante para futuras features (padrão arquitetural, decisão permanente):
adicionar em `memory/MEMORY.md`.

---

## Passo 4 — Commit (se houve mudança em docs)

```bash
git add LEARNINGS.md CLAUDE.md memory/MEMORY.md .claude/feature-plans/claude-terminal/M*/sprint.md
git commit -m "docs: add learnings from feature/<nome>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push origin main
```

---

## Passo 5 — Verificação final

```bash
# Confirmar que não há worktrees residuais
git worktree list

# Confirmar que o branch foi removido
git branch --list "feature/<nome>"

# Build deve continuar passando no main
swift build --configuration debug
```

---

## Passo 5.5 — Orientação

Após o cleanup, rode `/project-compass` para ver o estado atualizado do milestone:
- Se ainda há features `pending` no sprint.md, o compass mostrará a próxima feature e o comando exato para iniciar
- Se o milestone ficou 100% concluído, o compass apontará para o próximo milestone

```
/project-compass
```

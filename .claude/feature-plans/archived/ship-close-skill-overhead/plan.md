# Plan: ship-close-skill-overhead

## Problema

As skills `ship-feature` e `close-feature` têm dois bugs estruturais de ordering:

1. **`close-feature`**: usa paths relativos sem assertar `CWD = REPO_ROOT`. Em sessões
   executadas dentro de `.claude/worktrees/<feature>`, os writes de HANDOVER.md e
   CHANGELOG.md vão para a worktree (que é deletada no próximo passo) — não para main.
   Resultado: trabalho duplicado.

2. **`ship-feature`**: chama `merge_pull_request` antes de verificar se o CI passou.
   Se o CI falha pós-merge: branch de emergência, novo PR, novo CI. Uma feature vira 2-3 PRs.

## Assunções

- [verified][blocking] Os dois bugs são de reordenação/paths — não requerem mudança de arquitetura
- [verified][background] `git worktree list | head -1 | awk '{print $1}'` retorna REPO_ROOT absoluto independente de contexto de sessão

## Deliverables

### Deliverable 1 — Fix close-feature (absolute paths + assert)

**O que faz:** Adiciona `REPO_ROOT` assertion no início de close-feature e usa paths
absolutos em todos os file writes (HANDOVER.md, CHANGELOG.md, LEARNINGS.md, CLAUDE.md,
backlog.json). Adiciona assert antes de worktree remove.

**Critério de done:** Skill close-feature usa `$REPO_ROOT/HANDOVER.md` etc. em todos
os writes. Nenhum path relativo para arquivos da raiz do repo.

### Deliverable 2 — Fix ship-feature (CI gate antes do merge)

**O que faz:** Adiciona verificação de CI (gh pr checks) ANTES de `merge_pull_request`
no passo 6. Adiciona ASSERT pattern como comentário de guarda antes do merge.

**Critério de done:** Passo 6 de ship-feature verifica CI passing antes de mergear.

### Deliverable 3 — Assertions em start-feature

**O que faz:** Adiciona ASSERT antes de criar worktree: branch nao existe no remote.

**Critério de done:** start-feature tem guard antes do `EnterWorktree`.

### Deliverable 4 — Propagar para claude-kickstart

**O que faz:** Aplica os mesmos fixes nos templates de ship-feature e close-feature
em `/Users/rmolines/git/claude-kickstart/.claude/commands/`.

**Critério de done:** Templates do kickstart têm os mesmos guards.

## Arquivos a modificar

- `.claude/commands/ship-feature.md` — adicionar CI gate antes de `merge_pull_request` (passo 6)
- `.claude/commands/close-feature.md` — REPO_ROOT assert no início + absolute paths em todos os writes
- `.claude/commands/start-feature.md` — ASSERT antes de criar worktree
- `/Users/rmolines/git/claude-kickstart/.claude/commands/ship-feature.md` — idem ship
- `/Users/rmolines/git/claude-kickstart/.claude/commands/close-feature.md` — idem close

## Passos de execução

1. Editar `.claude/commands/close-feature.md` — adicionar REPO_ROOT no início do passo 1 e substituir paths relativos por absolutos
2. Editar `.claude/commands/ship-feature.md` — no passo 6, mover CI check para ANTES do merge
3. Editar `.claude/commands/start-feature.md` — adicionar ASSERT antes de `EnterWorktree`
4. Propagar fixes para os templates equivalentes no claude-kickstart

## Checklist de infraestrutura

- [ ] Novo Secret: nao
- [ ] Script de setup: nao
- [ ] CI/CD: nao muda
- [ ] Config principal: nao muda
- [ ] Novas dependencias: nao

## Rollback

```bash
git checkout main -- .claude/commands/ship-feature.md
git checkout main -- .claude/commands/close-feature.md
git checkout main -- .claude/commands/start-feature.md
```

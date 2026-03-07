# Plan: polish-kanban-integration

## Problema

`/polish` nao registra sessoes no `backlog.json`, entao `/project-compass` nao mostra historico de polish sprints.
Tres mudancas cirurgicas: `backlog.json` (schema), `polish.md` (write + close), `project-compass.md` (leitura).

## Assuncoes

- [assumed][background] `jq` disponivel na maquina do dev (verificado com `command -v jq` — skip silencioso se ausente)
- [assumed][background] `gh` CLI autenticado (ja usado em `close-feature.md` e `project-compass.md`)
- [verified][background] Nenhum dos 3 arquivos e hot file do CLAUDE.md — sem conflitos

## Deliverables

### Deliverable 1 — Schema + polish write + polish close

**O que faz:** adiciona `"chores": []` ao `backlog.json`; adiciona deteccao de `--close` no topo
de `polish.md`; reforca o Passo 5 com `swift test` + checklist UI; adiciona Passo 6b que escreve
o registro no `backlog.json` apos criar o PR.

**Criterio de done:** `backlog.json` tem `"chores": []`; `polish.md` tem secao `--close` funcional
e Passo 6b com jq write.

**Valida:** padrao REPO_ROOT + jq null-safe funciona para nova key `chores`.

**Deixa aberto:** leitura em `project-compass.md` (Deliverable 2).

**Execute `/checkpoint` antes de continuar para o Deliverable 2.**

### Deliverable 2 — project-compass leitura

**O que faz:** Phase 1c passa a extrair `chores[]`; Phase 3 ganha secao "Chores recentes" apos Pitches.

**Criterio de done:** `project-compass.md` mostra tabela de chores quando `chores[]` nao esta vazio,
omite a secao quando vazio.

**Valida:** integracao completa — polish escreve, compass le.

## Arquivos a modificar

- `.claude/backlog.json` — adicionar `"chores": []` como array top-level apos `"icebox"`
- `.claude/commands/polish.md` — (a) secao `--close` no topo; (b) Passo 5 com swift test + UI checklist; (c) Passo 6b chores write
- `.claude/commands/project-compass.md` — (a) Phase 1c extrai chores[]; (b) Phase 3 secao Chores recentes

## Passos de execucao

1. Editar `backlog.json` — adicionar `"chores": []` apos `"icebox"` [Deliverable 1]
2. Editar `polish.md` — adicionar deteccao `--close` no topo (antes do Passo 1) [Deliverable 1]
3. Editar `polish.md` — reforcar Passo 5 com `swift test` + RenderPreview + checklist manual [Deliverable 1]
4. Editar `polish.md` — adicionar Passo 6b apos criacao do PR: capturar prNumber/prUrl + jq write em chores[] [Deliverable 1]
5. **Execute `/checkpoint` — Deliverable 1 concluido**
6. Editar `project-compass.md` — Phase 1c: adicionar extracao de chores[] [Deliverable 2]
7. Editar `project-compass.md` — Phase 3: adicionar secao "Chores recentes" apos Pitches [Deliverable 2]

## Checklist de infraestrutura

- [ ] Novo Secret: nao
- [ ] Script de setup: nao
- [ ] CI/CD: nao muda
- [ ] Config principal: nao muda
- [ ] Novas dependencias: nao (jq e gh ja eram dependencias existentes)

## Rollback

```bash
git checkout main -- .claude/backlog.json .claude/commands/polish.md .claude/commands/project-compass.md
```

## Learnings aplicados

- **markdownlint MD040**: sempre usar language tag em code blocks (bash, json, text) — verificar nos 3 arquivos editados
- **markdownlint fences aninhadas**: usar 4 backticks para outer fence quando conteudo tem inner ``` — aplicavel em polish.md que exibe blocos de codigo bash dentro de secoes de exemplo
- **REPO_ROOT pattern**: `REPO_ROOT=$(git worktree list | head -1 | awk '{print $1}')` antes de qualquer write em backlog.json — identico ao close-feature.md

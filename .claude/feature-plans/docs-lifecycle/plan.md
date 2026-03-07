# Plan: docs-lifecycle

## Problema

LEARNINGS.md acumulou 739 linhas append-only sem critério de roteamento.
O resultado é três problemas: conteúdo duplicado com CLAUDE.md, seções do MEMORY.md que crescem sem cap, e close-feature que continua despejando entradas num arquivo morto.
Esta feature elimina LEARNINGS.md e institui roteamento direto para as camadas certas.

## Assunções

- [verified][blocking] LEARNINGS.md tem 739 linhas; após classificação, ~80% são DISCARD (duplicatas de CLAUDE.md ou MEMORY.md) — restam ~18 entradas novas a migrar
- [verified][background] MEMORY.md auto-memory está em `~/.claude/projects/-Users-rmolines-git-claude-terminal/memory/MEMORY.md` (não no git repo — esse arquivo não requer worktree)
- [assumed][background] Após mover `## Swift 6 Gotchas` e `## Release Pipeline` para topic files, MEMORY.md ficará abaixo de 200 linhas mesmo com as novas seções
- [assumed][blocking] close-feature.md e start-feature.md estão no git — precisam de worktree

## Questões abertas

**Explicitamente fora do escopo:**
- Reestruturar a tabela "Armadilhas conhecidas" do CLAUDE.md (vai crescer indefinidamente — problema para feature futura)
- Criar convenção de nomenclatura para futuros topic files além dos 3 planejados

## Deliverables

### Deliverable 1 — Topic files criados + MEMORY.md reestruturado

**O que faz:** Cria `memory/swift-concurrency.md`, `memory/swiftdata.md`, `memory/build-system.md`
com conteúdo movido do MEMORY.md + novas entradas do LEARNINGS.md.
Reestrutura o MEMORY.md: move seções verbosas para topic files (com links), adiciona
`## Patterns` e `## Decisions`, adiciona entradas novas de LEARNINGS.md nas seções certas.

**Critério de done:** MEMORY.md ≤ 200 linhas; 3 topic files existem; links em MEMORY.md apontam para eles; novas entradas incorporadas.

**Valida:** assunção de que mover `## Swift 6 Gotchas` e `## Release Pipeline` libera espaço suficiente.

**⚠️ Execute `/checkpoint` antes de continuar para o Deliverable 2.**

### Deliverable 2 — CLAUDE.md: 1 nova armadilha

**O que faz:** Adiciona entrada na tabela "Armadilhas conhecidas" do CLAUDE.md para
markdownlint fences aninhadas (4 backticks para outer fence).

**Critério de done:** Entrada adicionada e CLAUDE.md válido (sem quebra de formatação).

**⚠️ Execute `/checkpoint` antes de continuar para o Deliverable 3.**

### Deliverable 3 — close-feature.md step 1d substituído

**O que faz:** Substitui o passo 1d atual (write em LEARNINGS.md) por roteamento direto:
novo conhecimento vai para CLAUDE.md armadilhas (alta confiança) OU MEMORY.md/topic file
(tudo mais). Remove referência a `LEARNINGS.md` do passo 1d.

**Critério de done:** Passo 1d do close-feature.md não menciona LEARNINGS.md; critério de roteamento está explícito.

**⚠️ Execute `/checkpoint` antes de continuar para o Deliverable 4.**

### Deliverable 4 — start-feature.md step B.4 atualizado

**O que faz:** Substitui o passo B.4 atual (lançar subagente Explore para ler LEARNINGS.md)
por leitura seletiva: ler seções `## Decisions`, `## Patterns`, `## Gotchas` do MEMORY.md;
se existirem topic files linkados relevantes ao domínio, ler esses arquivos também.

**Critério de done:** Passo B.4 não menciona LEARNINGS.md; leitura é condicional (se MEMORY.md existir).

### Deliverable 5 — LEARNINGS.md removido

**O que faz:** Cria `LEARNINGS.md.bak` como backup, então remove `LEARNINGS.md` do git.

**Critério de done:** `LEARNINGS.md` não existe mais no worktree; `LEARNINGS.md.bak` existe em disco mas fora do git (.gitignore ou na raiz).

## Arquivos a modificar

**Fora do git (escritas diretas, sem worktree):**
- `~/.claude/projects/-Users-rmolines-git-claude-terminal/memory/MEMORY.md` — reestruturado
- `~/.claude/projects/-Users-rmolines-git-claude-terminal/memory/swift-concurrency.md` — criar
- `~/.claude/projects/-Users-rmolines-git-claude-terminal/memory/swiftdata.md` — criar
- `~/.claude/projects/-Users-rmolines-git-claude-terminal/memory/build-system.md` — criar

**No git (via worktree):**
- `CLAUDE.md` — +1 armadilha (markdownlint fences)
- `.claude/commands/close-feature.md` — passo 1d substituído
- `.claude/commands/start-feature.md` — passo B.4 atualizado
- `LEARNINGS.md` — removido (git rm)

## Passos de execução

1. Criar worktree `docs-lifecycle` para changes no git [setup]
2. Criar `memory/swift-concurrency.md` com: conteúdo movido de `## Swift 6 Gotchas Encountered` do MEMORY.md + nova entrada (enum associated value + Sendable) [Deliverable 1]
3. Criar `memory/swiftdata.md` com: padrões SwiftData dispersos + entrada ModelContainer na cena App [Deliverable 1]
4. Criar `memory/build-system.md` com: conteúdo movido de `## Release Pipeline` + template-sync !is_template + rm cert.p12 [Deliverable 1]
5. Reescrever MEMORY.md: comprimir `## Swift 6 Gotchas` e `## Release Pipeline` para links, adicionar `## Decisions` e `## Patterns` com novas entradas, adicionar entradas em `## SwiftUI Patterns` e `## Workflow` [Deliverable 1]
6. ⚠️ Execute `/checkpoint` — Deliverable 1 concluído
7. Adicionar armadilha markdownlint fences em CLAUDE.md (worktree) [Deliverable 2]
8. ⚠️ Execute `/checkpoint` — Deliverable 2 concluído
9. Substituir passo 1d em close-feature.md (worktree) [Deliverable 3]
10. ⚠️ Execute `/checkpoint` — Deliverable 3 concluído
11. Atualizar passo B.4 em start-feature.md (worktree) [Deliverable 4]
12. Criar LEARNINGS.md.bak e remover LEARNINGS.md via `git rm` (worktree) [Deliverable 5]
13. Commit + push da branch

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda (LEARNINGS.md não é validado pelo CI)
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

```bash
# Restaurar LEARNINGS.md (do backup ou do git)
git checkout HEAD -- LEARNINGS.md
# ou: cp LEARNINGS.md.bak LEARNINGS.md

# Reverter skills
git checkout HEAD -- .claude/commands/close-feature.md .claude/commands/start-feature.md CLAUDE.md

# MEMORY.md não tem rollback automático — está fora do git.
# Em caso de problema: o conteúdo original está nesta sessão e pode ser recriado.
```

## Learnings aplicados

- Topic files nomeados por domínio: swift-concurrency, swiftdata, build-system (padrão do research.md)
- MEMORY.md como indireção — seções comprimidas com links, não dump completo
- Critério binário no close-feature: alta confiança + sempre-relevante = CLAUDE.md; tudo mais = MEMORY.md ou topic file

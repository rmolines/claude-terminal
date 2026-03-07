# Plan: skill-flow-robustness

## Problema

O fluxo ship→close tem 3 pontos de fricção residual observados diretamente na sessão
que fechou `ship-close-skill-overhead`: (1) CI gate lê run antigo após fix push, podendo
levar a merge com CI vermelho; (2) sync-skills conflita com origin/main quando a feature
tocou skills; (3) regra "Nunca fazer commit" no close-feature está desatualizada e cria
confusão. Um quarto ponto menor: ship-feature passo 1 não instrui uso do sub-skill de commit.

## Assunções

- [verified][blocking] `gh run list --branch <branch> --limit 1` retorna o run mais
  recente para aquela branch — confirmado pela documentação do gh CLI
- [assumed][background] `git pull --rebase origin main` antes do sync-skills resolve o
  conflito porque local main é o único local onde o conflito ocorre (projeto solo)
- [verified][background] `make sync-skills` existe no projeto e executa o script em
  `.claude/commands/sync-skills.md`

## Questões abertas

**Explicitamente fora do escopo:**
- Reescrever o fluxo de propagação de skills (kickstart PR → merge → sync) — isso é
  uma feature separada
- Adicionar retry automático no CI gate — adicionaria complexidade desnecessária
- Corrigir o timing heurístico do `sleep 5` com polling — over-engineering para o risco

## Deliverables

### Deliverable 1 — Fix CI gate no ship-feature (passo 6)

**O que faz:** documenta e instrui o padrão correto de verificação de CI após re-push:
usar `gh run list` para obter o novo run ID, então `gh run watch <id>`.
Também melhora o passo 1 para referenciar o sub-skill de commit.

**Critério de done:** passo 6 do ship-feature.md descreve o padrão
`gh run list → gh run watch <id>` com instrução explícita para usar após re-push.

### Deliverable 2 — Fix sync-skills no close-feature (passo 1g)

**O que faz:** adiciona `git -C "$REPO_ROOT" pull --rebase origin main` antes de
`make sync-skills` no passo 1g. Atualiza a regra no rodapé para refletir que commits
de documentação/sync em main são esperados.

**Critério de done:** passo 1g do close-feature.md tem a linha de rebase antes de
`make sync-skills`. A regra no rodapé não diz mais "Nunca fazer commit" de forma absoluta.

## Arquivos a modificar

- `.claude/commands/ship-feature.md` — passo 1 (instrução de sub-skill) e passo 6 (CI gate)
- `.claude/commands/close-feature.md` — passo 1g (pull --rebase antes do sync) e seção Regras

## Passos de execução

1. Ler ship-feature.md completo para confirmar o passo 1 e passo 6 atuais [Deliverable 1]
2. Editar passo 1: adicionar instrução de usar `commit-commands:commit` sub-skill [Deliverable 1]
3. Editar passo 6: adicionar bloco com padrão `gh run list → gh run watch <id>` para
   uso após re-push de fix de CI [Deliverable 1]
4. Ler close-feature.md completo para confirmar passo 1g e seção Regras [Deliverable 2]
5. Editar passo 1g: adicionar `git -C "$REPO_ROOT" pull --rebase origin main` antes de
   `make sync-skills` [Deliverable 2]
6. Editar seção Regras: substituir "Nunca fazer commit, push ou PR" por redação precisa
   [Deliverable 2]

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

Reverter as edições com `git checkout -- .claude/commands/ship-feature.md .claude/commands/close-feature.md`

## Learnings aplicados

- `gh pr checks --watch` não aguarda novo run após re-push — usar `gh run list` + `gh run watch <id>`
- sync-skills precisa de pull --rebase antes de rodar para evitar conflito com squash-merge

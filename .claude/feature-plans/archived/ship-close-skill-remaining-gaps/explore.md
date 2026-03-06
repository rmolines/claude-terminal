# Explore: ship/close skill gaps pós-fix

## Pergunta reframeada

As alterações (ASSERT REPO_ROOT no close-feature + CI gate no ship-feature) resolveram
os problemas estruturais do fluxo ship→close? Ou há fricção residual que ainda precisa
ser endereçada?

## Premissas e o que não pode ser

- Premissa implícita: "resolver" significa que o fluxo roda sem intervenções manuais inesperadas
- Premissa implícita: o fluxo da sessão anterior é representativo do comportamento das skills
- Constraint: os dois bugs documentados (blind merge + paths relativos) eram os únicos problemas —
  isso NÃO é garantido; o fluxo pode revelar outros
- Não pode ser solução: "o agente se virou" — friction que exige desvio do script esperado é bug

## Estrutura do problema

Lendo o fluxo da sessão, dividindo em O que funcionou vs O que teve fricção:

### ✅ O que as alterações resolveram (confirmado no fluxo)

1. **CI gate antes do merge** — funcionou exatamente como projetado: `gh pr checks --watch`
   detectou lint vermelho, bloqueou o merge, o agente corrigiu, e só então mergeou. Sem este
   guard, o merge teria acontecido com CI vermelho (como era o comportamento anterior).

2. **REPO_ROOT assert no close-feature** — HANDOVER.md e CHANGELOG.md foram escritos em
   `/Users/rmolines/git/claude-terminal/` (main), não na worktree morta. O fix funcionou.

3. **ASSERT branch remota no start-feature** — não exercitado nesta sessão, mas o código está lá.

### ❌ Fricção residual identificada no fluxo (4 pontos)

#### Ponto 1 — Inline commit no ship-feature está quebrado

```text
⎿  Initializing…
⎿  Invalid tool parameters
⎿  Initializing…
⎿  Invalid tool parameters
⏺ Skill(commit-commands:commit)
```

O ship-feature tentou executar o commit de forma inline duas vezes, falhou, e só então
carregou o sub-skill `commit-commands:commit`. A skill descreve o passo 1 como "executar
git add + commit", mas não usa o sub-skill por default. Resultado: 2 tentativas com erro
antes de encontrar o caminho correto. Noisy e não-determinístico.

#### Ponto 2 — `gh pr checks --watch` lê run antigo após fix push

```text
⏺ Bash(git push && gh pr checks 53 --repo rmolines/claude-terminal --watch)
⎿  lint-and-validate  fail    3s   # ← run antigo, não o novo
```

Após pushear o commit de fix, `gh pr checks --watch` mostrou o resultado do run *anterior*
(que falhou) em vez de aguardar o novo run. O agente teve de:
1. Listar runs manualmente: `gh run list --branch ... --limit 3`
2. Extrair o run ID do novo run
3. Rodar `gh run watch <id>` com ID explícito

Isso não está documentado na skill. Um agente menos experiente mergearia com CI "vermelho"
porque viu o resultado do run antigo.

#### Ponto 3 — sync-skills durante close-feature cria conflito com main

```text
⎿  MM .claude/commands/SYNC_VERSION
⎿  M  .claude/commands/close-feature.md  # ← mesmo arquivo do PR que acabou de mergear
```

Sequência que gerou o conflito:

1. PR #53 squash-mergeado em `origin/main` (com close-feature.md + ship-feature.md atualizados)
2. `make sync-skills` executado dentro de `close-feature` → puxou kickstart → atualizou os mesmos arquivos localmente
3. Commit direto em `main` local com os docs + sync
4. `git push origin main` → rejected: origin/main já tinha o squash do PR
5. `git pull --rebase` → conflito em `.claude/commands/close-feature.md` (mesma versão, caminhos diferentes)
6. Agente resolveu com `--theirs` + stash drop

A skill não prevê esta sequência. Em projetos com sync-skills ativo, o close-feature
**sempre** vai criar este conflito quando a feature tocou skills.

#### Ponto 4 — kickstart em estado sujo bloqueia propagação

```text
⎿  error: Your local changes to the following files would be overwritten by checkout:
       .claude/commands/ship-feature.md
       .claude/commands/start-feature.md
```

O kickstart estava na branch `improve/audit-lei1-violations-20260305` com mudanças locais
não-commitadas. A skill não verifica isso antes de iniciar o fluxo de propagação. O agente
teve de fazer stash + checkout + stash pop manualmente.

## O gap

O fix da sessão anterior resolveu os **2 bugs estruturais documentados** (70% do problema).
Ficaram 4 pontos de fricção não-documentados, em ordem de impacto:

1. **`gh pr checks --watch` lê run antigo** — maior risco: pode levar a merge com CI vermelho
   (o objetivo do CI gate fica comprometido)
2. **sync-skills conflita com main** — sempre acontece quando feature toca skills; gera stash/rebase/conflict dance
3. **Inline commit quebrado** — noisy mas workaround automático (sub-skill)
4. **Kickstart sujo** — raro, mas bloqueia o fluxo sem aviso

## Hipótese

Os guards ASSERT resolveram os bugs de *corretude* (docs no lugar errado, merge sem CI).
A fricção residual é de *robustez*: os scripts assumem estado ideal (gh watch funciona como
esperado, kickstart limpo, sync-skills sem conflito). A skill precisa de um passo de
"verificar que o CI gate realmente aguardou o run correto" — não apenas `--watch`.

**Como chegamos aqui:**
- Descartado: "o agente se virou então está ok" — o objetivo é que o script funcione sem desvios
- Descartado: "são edge cases" — 3 dos 4 pontos ocorreram nesta sessão (não é edge case)
- Tensão: autonomia (merge sem confirmação) vs segurança (CI gate que funciona) — o CI gate
  atual tem um falso negativo conhecido (run antigo)

**Stress-test:** o ponto 2 (sync-skills conflita) pode ser eliminado simplesmente mudando
a ordem: fazer o commit de docs *antes* do sync-skills, ou fazer o sync-skills em branch
separada. Mas isso exige mudar o contrato do close-feature (que atualmente diz "nunca
fazer commit" — e violou essa regra na sessão).

## Próxima ação

**Veredicto:** melhoria em existente

**Próxima skill:** `/start-feature --deep`
**Nome sugerido:** `skill-flow-robustness`

**O que ficou consolidado:**
- `gh pr checks --watch` não é confiável como CI gate isolado: precisa de fallback com `gh run list + gh run watch <new-id>`
- sync-skills no close-feature sempre conflita quando a feature tocou skills — precisa de sequência específica (docs first, então sync)
- close-feature viola sua própria regra "nunca fazer commit" quando sincroniza docs para main — a regra está desatualizada

---

Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `skill-flow-robustness`.
O contexto está preservado em `.claude/feature-plans/ship-close-skill-remaining-gaps/explore.md`.

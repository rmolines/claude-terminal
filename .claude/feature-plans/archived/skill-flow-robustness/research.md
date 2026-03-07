# Research: skill-flow-robustness

## Descrição da feature

Corrigir 3 pontos de fricção residual no fluxo ship→close que não foram cobertos pelo fix anterior
(ASSERT guards + CI gate). Os problemas foram observados diretamente na sessão que fechou a feature
`ship-close-skill-overhead` — não são edge cases.

Fonte primária: `.claude/feature-plans/ship-close-skill-remaining-gaps/explore.md`

## Arquivos existentes relevantes

- `.claude/commands/ship-feature.md` — passo 6 (CI gate + merge) precisa de fix
- `.claude/commands/close-feature.md` — passo 1g (sync-skills) e regra final precisam de fix
- `.claude/commands/sync-skills.md` — lido para entender o que `make sync-skills` faz

## Padrões identificados

- Skills usam `gh pr checks --watch` para CI gate — adequado apenas no primeiro push
- `make sync-skills` faz `git checkout upstream/main -- .claude/commands/` + commit em main
- close-feature tem regra "Nunca fazer commit" mas na prática comita em 2 passos (1c e 1g)
- ship-feature passo 1 instrui "git add + git commit" sem sub-skill explícito

## Dependências externas

Nenhuma nova — apenas `gh` CLI e `git` que já estão em uso.

## Hot files que serão tocados

- `.claude/commands/ship-feature.md` — passo 6 e passo 1
- `.claude/commands/close-feature.md` — passo 1g e seção Regras

## Problemas identificados e suas causas raiz

### Problema 1 — CI gate lê run antigo (maior risco)

**Sintoma:** após push de fix de CI, `gh pr checks <pr> --watch` exibe o resultado do
run *anterior* (que falhou) em vez de aguardar o run disparado pelo novo push.

**Causa raiz:** `gh pr checks --watch` observa o estado atual dos checks do PR, que
pode refletir o run mais recente já completado — não necessariamente o novo run em
andamento. GitHub demora alguns segundos para registrar o novo run.

**Fix:** após cada push que segue a uma falha de CI, usar `gh run list --branch <branch>
--limit 1` para obter o ID do run mais recente, e então `gh run watch <id>`. Adicionar
nota explícita no passo 6 documentando esta sequência.

### Problema 2 — sync-skills conflita com origin/main

**Sintoma:** `git push origin main` rejeitado após `make sync-skills`, com conflito em
`.claude/commands/` durante o `git pull --rebase` subsequente.

**Causa raiz:** o passo 1g (sync-skills) não faz `git pull --rebase origin main` antes
de rodar `make sync-skills`. Local main pode ainda estar no commit anterior ao
squash-merge do PR. O squash-merge já colocou as skills atualizadas em origin/main. O
`make sync-skills` então cria um commit com as mesmas files, mas em cima de um ancestral
diferente — resultando em conflito no rebase.

**Fix:** antes de `make sync-skills`, sempre executar `git -C "$REPO_ROOT" pull --rebase
origin main`. Isso garante que local main está em cima do squash-merge antes de sync.

### Problema 3 — Regra "Nunca fazer commit" desatualizada

**Sintoma:** a regra no rodapé do close-feature.md diz "Nunca fazer commit, push ou PR"
mas a própria skill faz commits em 2 momentos (passo 1c: MEMORY.md; passo 1g: sync-skills).

**Causa raiz:** a regra foi escrita para prevenir commits da *feature* em si, mas foi
redigida de forma absoluta — o que cria confusão quando o agente comita documentação.

**Fix:** atualizar a regra para refletir a realidade: "Nunca commitar código da feature
em main — commits de documentação e sync em main são permitidos e esperados."

### Problema 4 — Inline commit no ship-feature (menor risco)

**Sintoma:** ship-feature passo 1 instrui `git add + git commit` de forma genérica;
o modelo tentou usar ferramenta interna com parâmetros incorretos 2x antes de carregar
o sub-skill `commit-commands:commit`.

**Fix:** adicionar instrução explícita: "usar o sub-skill `commit-commands:commit`" no
passo 1 do ship-feature.

## Riscos e restrições

- Fix do problema 2 (pull --rebase antes do sync) pode criar conflito em projetos onde
  local main tem commits pendentes que também tocam `.claude/commands/`. Nesses casos,
  o conflito é inevitável e o usuário precisa resolver manualmente — mas é explícito,
  não silencioso.
- Problemas 3 e 4 são mudanças de texto — sem risco técnico.
- Problema 1 depende de timing: `sleep 5` é heurístico. Se GitHub demorar mais para
  registrar o run, o `gh run list` ainda pode retornar o run antigo.
  Mitigação: verificar que o run retornado foi criado *após* o push (comparar timestamps).

## Fontes consultadas

- `.claude/feature-plans/ship-close-skill-remaining-gaps/explore.md` (observação direta)
- `.claude/commands/ship-feature.md` (código atual)
- `.claude/commands/close-feature.md` (código atual)
- `.claude/commands/sync-skills.md` (para entender o que make sync-skills faz)

# Explore: Ship/Close Skill Overhead — Bugs Estruturais

## Pergunta reframeada

As skills `ship-feature` e `close-feature` têm dois bugs estruturais de ordering que causam
retrabalho sistemático: (1) documentação escrita em branch morta pós-merge, (2) merge executado
antes de verificar se o CI passou. O overhead não é intrínseco ao workflow — é recuperação
previsível de falhas evitáveis.

## Premissas e o que não pode ser

- **Premissa do usuário**: as skills são lentas por serem complexas
- **Realidade**: as skills fazem work duplicado por ordering incorreto, não por complexidade
- **Premissa implícita nas skills**: o agente tem CWD conhecido e estado de sistema fixo
- **Realidade**: multi-worktree + CI assíncrono quebram essas premissas silenciosamente
- **O que não pode ser a solução**: adicionar mais passos / mais confirmações do usuário
- **O que não pode ser a solução**: mover docs para fora do workflow (perde rastreabilidade)

## Mapa do espaço

**Bug 1 — Docs na branch morta (close-feature)**

A skill escreve HANDOVER.md e CHANGELOG.md usando paths relativos, sem assertar que
`CWD == REPO_ROOT`. Quando o agente está dentro de `.claude/worktrees/<feature>`, os writes
vão para a worktree, não para main. A worktree é deletada no próximo passo, docs desaparecem,
agente reescreve tudo diretamente em main. Trabalho feito duas vezes.

Evidência do log:

```text
git checkout main → "would be overwritten by checkout: CHANGELOG.md, HANDOVER.md"
→ git add + commit na feature branch
→ switch para main
→ "os docs do close foram perdidos na troca de branch"
→ reaplicando diretamente no main [repete todas as edições]
```

**Bug 2 — Blind merge (ship-feature)**

A skill chama `merge_pull_request` e SÓ DEPOIS roda `gh run watch`. Se CI falha: branch de
emergência, novo PR, novo merge, nova espera de CI. Uma feature vira 2-3 PRs.

Evidência do log:

```text
merge_pull_request → PR #50 mergeado
gh run watch → MD022/blanks-around-headings FAIL
→ git checkout -b fix/changelog-md022 origin/main
→ fix → PR #51 → merge → CI verde
```

**O que o mercado faz (research):**

- **semantic-release**: docs sempre escritos ANTES do tag, na mesma operação atômica. Nunca
  pós-merge em branch separada.
- **release-please**: changelog mora NO PR de release — revisado antes do merge, não escrito
  depois.
- **changesets**: changeset file viaja com o feature PR. Intent documentado atomicamente com o
  código.
- **GitHub auto-merge** (`gh pr merge --auto`): abordagem canônica para "merge só quando CI
  passar" — delega para o GitHub esperar pelas status checks sem polling loop.
- **Consensus**: commit de docs direto em main após merge, sem PR associado, sem CI gate, é
  considerado o pior padrão de documentação (bypassa review, polui commit graph, não
  reproduzível).

## O gap

O que não existe nas skills atuais — e que todos os sistemas profissionais têm:

1. **Precondition assertions antes de steps destrutivos.** As skills são scripts imperativos
   (faça A, B, C). Não têm guards. Falham silenciosamente quando o contexto difere do assumido.

2. **Separação clara entre "docs que viajam com o código" vs "docs retrospectivos".** O
   CHANGELOG (o que mudou) pode ir no commit antes do PR abrir. O HANDOVER (o que foi
   aprendido) é retrospectivo — legítimo pós-merge, mas precisa de absolute paths para não
   cair em branch morta.

3. **CI como gate, não como witness.** Hoje a skill assiste ao CI depois de já ter mergeado.
   A correção mínima (`gh run watch` antes de `merge_pull_request`) não requer mudança de
   arquitetura — apenas reordenação de dois passos.

## Hipótese

**As skills são imperativos sem guards, escritas assumindo um contexto de execução que o
ambiente multi-worktree viola.** A solução tem duas partes ortogonais:

**Fix cirúrgico** (mínimo viável):
- `ship-feature`: mover `gh run watch` para ANTES de `merge_pull_request`
- `close-feature`: assertar `REPO_ROOT=$(git worktree list | head -1 | awk '{print $1}')` no
  início e usar absolute paths em todos os file writes

**Fix arquitetural** (incluso no escopo — aprovado):
- Adicionar padrão "context assertion" antes de cada step destrutivo em ship-feature
  e close-feature, e propagar o template para as demais skills (start-feature, fix, etc.)
- Formato padrão:
  ```text
  ASSERT antes de prosseguir: [invariante]. Se falso, PARAR e reportar ao usuario.
  ```
- Assertions a adicionar:
  - close-feature, antes de qualquer write: REPO_ROOT absolute path confirmado
  - close-feature, antes de worktree remove: CWD nao esta dentro do worktree
  - ship-feature, antes de merge_pull_request: CI passing (gh run list --branch HEAD)
  - start-feature, antes de criar worktree: branch nao existe no remote
- Propagar padrao para close-feature no claude-kickstart tambem

**Como chegamos aqui:**
- Descartado: mover toda documentação para pré-merge (changesets model) — HANDOVER.md e
  LEARNINGS.md são genuinamente retrospectivos, perdem valor se escritos antes do merge
- Descartado: GitHub auto-merge como solução — requer branch protection settings permanentes
  (decisão de governança, escopo maior que uma skill fix)
- Resolvido: tensão entre "docs retrospectivos são legítimos" e "docs pós-merge sem PR são
  anti-pattern" — a resposta é que commits docs-only direto em main são aceitáveis SE o fix
  de absolute paths garantir que eles realmente aterrem em main

**Stress-test:** O assert de REPO_ROOT pode falhar se o agente iniciar close-feature numa
sessão nova sem saber qual é o worktree root. Contra-argumento: `git worktree list | head -1`
sempre retorna o REPO_ROOT independente de contexto de sessão — é uma syscall, não memória.

## Proxima acao

**Veredicto:** melhoria em existente — dois bugs cirurgicos nas skills `ship-feature` e
`close-feature` (projeto `claude-terminal` + template `claude-kickstart`).

**Proxima skill:** `/start-feature ship-close-skill-overhead`
**Nome sugerido:** `ship-close-skill-overhead`

**O que ficou consolidado:**
- Bug 1 root cause: close-feature usa paths relativos sem assertar CWD = REPO_ROOT
- Bug 2 root cause: ship-feature chama merge_pull_request antes de gh run watch
- Fix minimo: (1) absolute paths via git worktree list em close-feature; (2) gh run watch
  antes de merge_pull_request em ship-feature
- Fix arquitetural incluso: padrao "ASSERT antes de prosseguir" antes de cada step destrutivo
- Propagar assertions para todas as skills afetadas (ship, close, start-feature) + claude-kickstart

---
Faca `/clear` para limpar a sessao e entao rode `/start-feature ship-close-skill-overhead`.
O contexto esta preservado em `.claude/feature-plans/ship-close-skill-overhead/explore.md`.
---

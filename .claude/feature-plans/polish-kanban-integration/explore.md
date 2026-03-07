# Explore: Polish, Native Tasks e Kanban

## Pergunta reframeada

Como integrar três sistemas de rastreamento de trabalho que hoje vivem em silos distintos —
`/polish` (lista ad-hoc de itens), Claude Code native tasks (TodoWrite/TaskCreate, sidebar da sessão),
e `backlog.json` (fonte de verdade do projeto) — de forma que fluam naturalmente sem duplicação de estado
e sem degradar o sinal de cada camada?

## Premissas e o que não pode ser

- **Premissa implícita 1:** Os três sistemas estão quebrados por não se falarem — a separação é um problema.
- **Premissa implícita 2:** "Conversar" significa sync bidirecional ou integração tight.
- **Constraint confirmado:** Native tasks são _working memory_, não _records_. São criadas,
  abandonadas e recriadas durante o raciocínio de um agente — tratá-las como sync target
  degrada ambos os sistemas.
- **Constraint confirmado:** `/polish` é intencionalmente leve. Forçar pré-registro no
  `backlog.json` antes de uma sessão de polish adiciona cerimônia que destrói o valor da skill.
- **O que não pode ser a solução:** sync bidirecional entre qualquer combinação dos três
  sistemas. O custo de conflito e drift supera qualquer benefício de visibilidade.

## Mapa do espaço

**Três níveis de abstração distintos (confirmado por todas as 4 pesquisas):**

- `backlog.json` — **nível produto**: feature é uma unidade de valor entregue. Horizonte: semanas/meses.
- `/polish` items — **nível implementação**: item é uma mudança pontual com locus específico.
  Horizonte: sessão/branch.
- Native tasks (TaskCreate/TodoWrite) — **nível execução**: task é um passo no raciocínio
  do agente. Horizonte: context window.

**O que o mercado fez com esse problema:**

- **Linear**: Cycle (sessão) vs. Issue (projeto) — tipos estruturalmente distintos, não apenas
  status fields no mesmo record. Rollover automático de itens não concluídos.
- **GTD**: Projects List (outcome noun) vs. Next Actions List (pointer executável) — exatamente
  1 próxima ação visível por projeto. Sem nesting no sistema de execução.
- **CI/CD** (GitHub Actions, Buildkite): Pipeline schema (estático, versionado) vs. Build run
  (instância efêmera). O schema nunca é escrito pela run; a run sempre é uma projeção do schema.
- **Shape Up**: Pitches/bets/features como tipos separados com lifecycle diferente —
  exatamente o modelo que `backlog.json` já implementa.

**Claude Code native tasks — o que realmente são:**

- `TaskCreate/TaskList/TaskUpdate` = session-ephemeral (destruídos no final da sessão, não persistem entre `/clear`)
- `TodoWrite/TodoRead` = session-ephemeral por padrão; persistem entre sessões apenas com
  `CLAUDE_CODE_TASK_LIST_ID` env var (escreve em `~/.claude/tasks/<id>/`)
- Único hook disponível: `TaskCompleted` — não há hooks para create/update
- Task* tools **bypassam** `PreToolUse`/`PostToolUse` hooks completamente
- Sem mecanismo nativo para sync com arquivos externos

## O gap

- **Sessões de polish são invisíveis para `/project-compass`** e para agentes futuros.
  Não existe registro no `backlog.json` de que um polish sprint aconteceu — só os commits/PR
  no git (difícil de acessar programaticamente por skills).
- **`backlog.json` não tem conceito de "chore"** — só milestones, features, pitches, icebox.
  Melhoras técnicas cíclicas (polish sprints) não têm lugar no schema atual.
- **Native tasks são invisíveis além da sessão** — mas isso é by design. O gap real não é
  "como torná-las persistentes", é "qual informação da sessão vale preservar no nível projeto".
- **`/polish` não fecha o loop com o kanban** — o usuário pode rodar `/project-compass`
  depois de um polish sprint e não ver nenhum sinal de que o polish aconteceu.

## Hipótese

A integração correta não é sync — é **event emission unidirecional e post-facto**.
Ao abrir o PR, `/polish` escreve um único registro em um array `chores` novo em `backlog.json`
(uma entrada por sprint, não por item). Esse registro é append-only, não tem upstream coupling,
e fecha o loop de visibilidade sem introduzir pré-registro ou complexidade de sync.

Native tasks permanecem isoladas: são scratch space de execução, não deveriam ser
registradas no kanban. O único sinal de sessão que vale capturar é "um polish sprint aconteceu,
cobriu esses itens, tem esse PR" — e esse sinal já está disponível no momento certo (PR open).

**Como chegamos aqui:**
- Descartado: sync bidirecional — todos os 4 agentes convergem para o mesmo ponto de falha
  (conflitos, drift, noise no kanban, cerimônia que quebra o fluxo leve do polish).
- Descartado: native tasks como sync target — são working memory, escrever no kanban
  degradaria o sinal de "o que o projeto precisa".
- Tensão resolvida: "o usuário traz a lista de itens na cabeça" vs. "o kanban deveria saber
  o que foi feito" → resolução via post-facto append (usuário ainda traz lista; kanban aprende
  depois, não antes).

**Stress-test:** O argumento contra mais forte é que adicionar qualquer write-back de `/polish`
para `backlog.json` cria um coupling point que vai drift. Em worktrees, o path para o
`backlog.json` canônico já é conhecido como armadilha (ver CLAUDE.md). Além disso,
`/project-compass` teria que ser atualizada para ler o array `chores` — o que expande a
superfície de duas skills para mudar de forma coordenada.

## Próxima ação

**Veredicto:** melhoria em existente — duas skills afetadas (`/polish` + `/project-compass`)
e schema evolution em `backlog.json`.

**Próxima skill:** `/start-feature --discover`
**Nome sugerido:** `polish-kanban-integration`

**O que ficou consolidado:**
- Native tasks (TaskCreate/TodoWrite) não devem ser integradas ao `backlog.json` — são
  working memory por design, não project records.
- A separação atual entre os três sistemas é correta em nível estrutural; o único gap real
  é de visibilidade retroativa (polish sprints são invisíveis ao project-compass).
- Qualquer write-back para `backlog.json` deve ser post-facto e append-only, nunca
  pré-registro obrigatório.

---

Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `polish-kanban-integration`.
O contexto está preservado em `.claude/feature-plans/polish-kanban-integration/explore.md`.

---

Cole na nova sessão após /clear:

```text
Explore "polish-kanban-integration" concluido.
Contexto salvo em: .claude/feature-plans/polish-kanban-integration/explore.md
Proxima skill: /start-feature --discover polish-kanban-integration
```

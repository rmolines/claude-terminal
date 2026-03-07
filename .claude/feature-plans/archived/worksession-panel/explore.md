# Explore: Work Session Panel — Mission Control para Trabalho Paralelo

## Pergunta reframeada

Como deve ser a interface de gestão de N streams de trabalho paralelo onde cada stream tem três dimensões simultâneas: estado git (worktree/branch), estado do agente (Claude Code rodando/idle/HITL), e estado de progresso (fase da skill/task)? A questão não é "melhorar o visual da aba Worktrees" — é "modelar a entidade correta que nunca foi modelada".

## Premissas e o que não pode ser

- **Premissa implícita 1:** "Worktree" é a unidade de trabalho certa. Na verdade, worktree é um detalhe de git. A unidade real é "feature em desenvolvimento" — que tem três dimensões (git + agente + task).
- **Premissa implícita 2:** O problema é visual/estético. O problema real é de modelo mental: o usuário precisa fazer join mental de três views separadas para entender o estado de uma entidade que deveria ser única.
- **Premissa implícita 3:** A solução é enriquecer a WorktreesView. A solução pode ser substituir WorktreesView + DashboardView por uma única view de entidade composta.
- **Constraint — o que não pode ser a solução:** Simplesmente adicionar mais colunas à lista atual. O problema não é informação faltando — é que a entidade modelada é a errada. Adicionar "status do agente" como coluna extra na WorktreesView mantém o problema (git como entidade primária, agente como atributo secundário) quando os dois são co-primários.
- **Constraint — alarm fatigue:** Pesquisa de ICU mostra que sistemas que mostram muita informação passiva criam dessensibilização. A solução não pode exibir mais dados — deve proteger a atenção para o que importa.
- **Constraint — escala:** Swim lanes e grids degradam acima de 5-8 entidades paralelas. A solução precisa de um mecanismo de ordenação automática por urgência, não apenas lista estática.

## Mapa do espaço

**Ferramentas da categoria "gestor de agentes paralelos" existentes:**

- **Vibe Kanban** (BloopAI, 2025) — Kanban board com worktrees por card, streaming de output do agente em tempo real via WebSocket, coluna "Review" com diff. Web UI. Sem HITL, sem token tracking. O mais próximo do modelo correto — mas sem o canal de aprovação humana.
- **Superset** (superset.sh, março 2026) — Dashboard Electron com todos os agentes visíveis simultaneamente, status em tempo real, diff viewer, git worktree isolation. Mais completo em fleet view. Sem HITL approval nativo. Não macOS nativo.
- **GitHub Agent HQ** (fev 2026) — Dashboard cross-agent; vê progresso após conclusão, não durante. Abstração "task → agente → PR" é certa para workflows assíncronos.
- **Cursor 2.0** (out 2025) — Até 8 agentes paralelos em worktrees cloud isoladas, mas UI de um agente por vez. Fleet view não existe; há sidebar de cards, não dashboard.
- **Devin 2.0** — "Progress tab" (plano com step atual destacado) é mais scannable que terminal raw. Sessões como lista hierárquica no sidebar.
- **Claude Squad / CCManager / ccswarm** — TUI no terminal, sem GUI. Um agente em foco por vez. Sem HITL, sem token tracking.

**Fundações teóricas relevantes:**

- **Situation Awareness (Endsley, 1996):** Operadores com múltiplas entidades sob monitoramento gastam 80% da atenção nas 20% entidades em estado transitório. O display deve tornar "entidades em transição" visualmente salientes sem obscurecer as estáveis.
- **Kanban blocked state:** A distinção entre "in progress" e "blocked" (HITL pending) é a mais importante no sistema. Card bloqueado deve ser visualmente congelado e prioritizado para o topo.
- **RTS minimap pattern:** Alertas têm posição espacial — o usuário sabe "onde" no mapa, não só "que houve um alerta". Para Claude Terminal: HITL poderia mostrar qual worktree está bloqueada no overview sem precisar abrir detalhes.
- **ICU alarm fatigue:** Sistemas que notificam demais treinam operadores a ignorar tudo. Menos alarmes = mais segurança. Só HITL e ERROR justificam atenção visual agressiva.
- **C2 Common Operating Picture:** Estado externo elimina memória de trabalho. O operador não constrói o estado na cabeça — o sistema o mantém. A WorkSession List deve ser a "COP" do dev.

## O gap

**O que genuinamente não existe no app atual:**

1. **A entidade "WorkSession" não existe.** DashboardView modela agentes. WorktreesView modela git worktrees. TaskBacklogView modela tasks. Nenhuma view unifica as três dimensões em uma entidade única. O usuário faz o join mental toda vez.

2. **Ordering automático por urgência não existe.** A lista atual é estática (ordem de criação do worktree). Com 4+ agentes, o usuário deve ler cada linha para detectar qual precisa de atenção. O custo é linear no número de agentes.

3. **HITL inline no overview não existe.** Para aprovar um HITL, o usuário navega: DashboardView → AgentCard → HITL Panel. O painel flutuante existe, mas não há sinalização de qual worktree está bloqueada no contexto do painel de trabalho paralelo.

4. **Estado relativo ao plano não existe.** A view mostra estado absoluto (commits ahead, files changed). Não mostra "o agente está onde deveria estar no plano?" — a pergunta que o usuário realmente quer responder.

**O que o mercado ainda não resolveu:**

- Nenhuma ferramenta tem HITL approval nativo integrado ao fleet view (Vibe Kanban, Superset, Cursor — todos sem isso)
- Nenhuma ferramenta é nativa macOS com NSStatusItem + menu bar badge para HITL
- Nenhuma ferramenta combina git state + agent state + task state em uma entidade única e ordenável por urgência

## Hipótese

**A WorktreesView e o DashboardView são duas projeções parciais da mesma entidade que nunca foi modelada: o WorkSession.** Criar essa entidade composta como a unidade central de uma nova view — que unifica git state, agent state, e task state — eliminaria o join mental que o usuário faz repetidamente e permitiria ordering automático por urgência.

A view resultante não seria uma "aba de worktrees melhorada". Seria o painel central do app, substituindo ou fundindo as duas views atuais. Cada linha seria um WorkSession com estado dominante em Tier 1 (identidade + estado urgente), progresso em Tier 2 (fase da skill, atividade recente), e git state em Tier 3 (colapsado por padrão).

**Como chegamos aqui:**

- Descartamos "enriquecer WorktreesView com mais colunas" — manteria git como entidade primária, que é a premissa errada
- Descartamos "dashboard estilo Kanban board" — para N<8 agentes com HITL como evento crítico, card grid é mais pesado que necessário; lista com ordering automático é mais eficiente
- Resolvemos a tensão entre "mostrar tudo" (Superset) e "mostrar pouco" (WorktreesView atual) com hierarquia de tiers: Tier 1 sempre visível, Tier 2 sempre visível, Tier 3 colapsado; nenhuma informação é removida, apenas deprioritizada

**Stress-test:** O WorkSession como entidade nova exige que o app mantenha o vínculo entre worktree, agente e task em runtime — o que hoje não existe no modelo de dados. Se um agente for iniciado sem task, ou se uma worktree existir sem agente associado, a entidade fica incompleta. O stress-test real é: o modelo de dados (SwiftData) suporta WorkSession como entidade derivada, ou requer migração de schema com VersionedSchema? Isso pode ser a principal fricção técnica de implementação.

## Próxima ação

**Veredicto:** Melhoria em existente — redesign de uma feature do Claude Terminal

**Próxima skill:** `/start-feature --discover`
**Nome sugerido:** `worksession-panel`

**O que ficou consolidado:**

- **A entidade correta é WorkSession = (worktree + agente + task).** As três dimensões são co-primárias. Nenhuma é atributo da outra.
- **Ordering automático por urgência é não-negociável.** `HITL_PENDING > ERROR > RUNNING > DONE > IDLE`. Sem isso, o custo cognitivo é linear no número de agentes.
- **HITL inline no overview é o diferencial real.** Nenhum competidor tem isso. É o moat do app e deve ser o elemento de design mais bem resolvido no WorkSession panel.

---

Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `worksession-panel`.
O contexto está preservado em `.claude/feature-plans/worksession-panel/explore.md`.

────────────────────────────────────────────────
Cole na nova sessão após /clear:

Explore "worksession-panel" concluído.
Contexto salvo em: .claude/feature-plans/worksession-panel/explore.md
Próxima skill: /start-feature --discover worksession-panel
────────────────────────────────────────────────

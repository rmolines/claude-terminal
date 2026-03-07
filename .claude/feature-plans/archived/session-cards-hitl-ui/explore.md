# Explore: Session Cards e HITL Interaction UI

## Pergunta reframeada

Como projetar a UI de monitoramento de sessões do Claude Terminal — cards na barra lateral e interação HITL — de forma que um único operador possa acompanhar N sessões concorrentes e responder a permission dialogs sem abrir o terminal e sem trocar de janela?

## Premissas e o que não pode ser

- O usuário já tem o app com sessões ativas e o mecanismo HITL funcionando (socket + PTY injection)
- O fluxo atual com iTerm é custoso porque não há sinal de prioridade — o operador monitora passivamente todos os painéis
- HITL é esporádico mas urgente: Claude está bloqueado, custo acumulando
- **Premissa implícita a questionar:** o card não precisa ser um mini-terminal — ele deve mostrar *estado*, não *dados brutos*
- **Constraint: não pode ser** "mais terminais ou painéis" — isso é exatamente o problema atual
- **Constraint:** o terminal não pode ser a superfície primária — se for, o operador está sempre em modo Response para uma sessão, degradado para as outras N-1
- **Constraint:** aprovar/rejeitar HITL não pode exigir ler o terminal completo para a maioria dos casos — senão treina o operador a aprovar tudo sem ler (automation complacency)

## Mapa do espaço

**Ferramentas de monitoramento existentes (nenhuma resolve o problema central):**
- **opcode** (https://opcode.sh) — GUI companion, cards de sessão, mas sem HITL nativo; aconselha `--dangerously-skip-permissions`
- **claude-code-monitor** (https://github.com/onikan27/claude-code-monitor) — dashboard web em tempo real, prova que "sidebar + click para focar" é o mental model dominante, mas switch de janela de terminal
- **ccmanager** (https://github.com/kbwo/ccmanager) — TUI com worktree awareness, sem camada HITL
- **Claudia** (https://getclaudia.org) — GUI desktop, usage tracking, sem interception de permission dialogs
- **VS Code extension** — issues abertos (#25520, #26851) onde HITL de sub-agentes falha silenciosamente

**Teoria de controle supervisório (Sheridan, Endsley):**
- Loop supervisório: plan → teach → **monitor** → **intervene** → learn. O card é o monitor; o painel HITL é o intervene
- Endsley 3-level situation awareness: L1=percepção (rodando?), L2=compreensão (o que está fazendo?), L3=projeção (se aprovar, o que acontece?)

**Padrões de UI de operador multi-stream:**
- Bloomberg Terminal: 4 painéis paralelos, painéis de fundo continuam atualizando sem puxar foco
- AlertWatch (anestesiologia): ícones de sistema de órgãos com semáforo de cor — estado, não dados. Melhor analogia para session cards
- SCADA/ISA-18.2: menos alarmes com mais densidade de informação por alarme é mais seguro que mais alarmes com menos contexto
- PagerDuty/OpsGenie: fila de itens acionáveis com severidade, não alertas contínuos

**Pesquisa em interrupção (Iqbal & Bailey, CHI 2008):**
- Interrupções em task breakpoints custam significativamente menos que interrupções mid-task
- Distinção entre HITL *deferível* (pode esperar 30s) vs *urgente* (Claude bloqueado agora)

## O gap

1. **Nenhuma ferramenta existente intercepta HITL natively** — todas redirecionam ao terminal ou pulam as permissões. claude-terminal é o único com socket hook + PTY injection nativo, mas a UI não explora isso: o painel HITL atual é separado dos cards de sessão
2. **Nenhum card de sessão usa situation awareness theory** — a maioria mostra logs brutos, não estado. O campo L1/L2/L3 não está implementado
3. **Não existe fila visual de HITLs** — se múltiplas sessões pedem permissão ao mesmo tempo, é primeiro-que-chega modal
4. **O "Context Load" — estado cognitivo oculto** — é a maior fonte de custo de atenção mas nenhum design o trata: quando o operador decide engajar uma sessão, precisa reconstruir o modelo mental dela antes de agir

## Hipótese

O claude-terminal já tem o único mecanismo nativo de HITL do mercado. O que falta é a camada de supervisão: redesenhar os session cards usando o modelo de 3 níveis da situation awareness (Endsley) — L1 = semáforo de estado no card, L2 = tarefa + ferramenta atual, L3 = contexto de risco dentro do painel HITL — de forma que o operador possa tomar a decisão sem abrir o terminal na maioria dos casos, e o terminal se torne um drill-down deliberado, não a superfície primária.

**Como chegamos aqui:**
- Descartado: "melhorar o card com mais informação de log" — log bruto no card é ruído, não estado; piora o monitoring
- Descartado: painel HITL como modal sequencial — múltiplas sessões simultâneas exigem fila visual, não stacking
- Tensão resolvida: "quanto contexto mostrar no HITL sem virar mini-terminal" — mostrar risk surface computada (o que é irreversível, o que é destrutivo) + opção de expandir terminal inline para casos complexos

**Stress-test:** Algumas decisões HITL genuinamente exigem ver o output do terminal para serem tomadas com segurança (e.g., `git push` depois de uma sequência de commands — o operador precisa saber se os testes passaram). Se o painel HITL não mostrar contexto suficiente, o operador vai ou aprovar cegamente (pior) ou abrir o terminal de qualquer jeito (status quo). A hipótese só funciona se o painel HITL tiver uma ação "ver terminal" que expanda inline — caso contrário cria uma ilusão de supervisão sem substância.

## Especificação emergente: card + HITL

### Session Card — três tiers de informação

**Tier 1 — pré-atentivo (parseable sem fixação):**
- Status badge: `running` / `waiting-HITL` / `stuck` / `done` / `error` — cor + glyph único
- HITL flag: badge de alto contraste quando input humano está pendente (visualmente dominante)

**Tier 2 — leitura rápida (uma fixação, ~200ms):**
- Task description: intenção original do operador, não resumo do Claude. 1-2 linhas max
- Current tool: "Editando /src/auth.ts" ou "Rodando testes" — onde no trabalho Claude está
- Elapsed since last status change: "Preso há 8 min" é acionável; "iniciado há 47 min" é ruído

**Tier 3 — leitura deliberada (triage, não monitoring):**
- Last action / última linha de output: uma linha truncada, sniff test antes de abrir o terminal
- Token cost: apenas quando cruza threshold relevante, não sempre

### HITL Panel — mínimo viável

- Ferramenta/ação solicitada (ex: `Bash: git push origin main`)
- Nome da sessão (task name, não session ID)
- Risk surface computada: o que é irreversível, o que é destrutivo, o que é network-external
- Approve / Reject apenas
- Ação "ver terminal" que expande inline (não abre iTerm)
- Para múltiplas HITLs simultâneas: fila visual persistente (strip), não modais empilhados

### Princípio estrutural

O terminal é um modo, não uma view persistente. A superfície primária é o grid/lista de sessões. O terminal é um drill-down. O painel HITL flutua acima de ambos. Esta ordem não é preferência de UX — é consequência direta de como atenção supervisória funciona sob carga assíncrona concorrente.

## Próxima ação

**Veredicto:** melhoria em existente

**Próxima skill:** `/start-feature --discover`
**Nome sugerido:** `session-cards-hitl-ui`

**O que ficou consolidado:**
- Automation complacency é o risco central: design deve garantir que decisões perigosas *pareçam estruturalmente diferentes* das rotineiras — isso vem de conteúdo no painel HITL, não de badges de urgência
- Nenhum concorrente resolve HITL nativamente — a vantagem do claude-terminal está no socket hook; a UI deve explorar isso, não esconder
- O terminal deve ser modo/drill-down, nunca superfície primária — qualquer design que coloque o terminal de uma sessão como view default quebra o modelo supervisório para N>=3

---
Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `session-cards-hitl-ui`.
O contexto está preservado em `.claude/feature-plans/session-cards-hitl-ui/explore.md`.

────────────────────────────────────────────────
Cole na nova sessão após /clear:

Explore "session-cards-hitl-ui" concluído.
Contexto salvo em: .claude/feature-plans/session-cards-hitl-ui/explore.md
Próxima skill: /start-feature --discover session-cards-hitl-ui
────────────────────────────────────────────────

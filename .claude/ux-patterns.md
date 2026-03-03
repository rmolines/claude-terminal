# UX Patterns: Claude Terminal

_Decision table de interação. Cresce por feature — cada nova decisão de UX vira uma linha aqui.
Status: `codified` = implementado e validado | `proposed` = aprovado mas não implementado | `open` = decisão pendente._

---

## Pattern: Monitoring vs. Decision

**When:** Há informação sobre o estado de um agente (tokens, status, CWD, fase da skill).
**Then:** Exibir como badge/dot passivo — sem ação requerida. Reservar interrupção ativa (notificação, badge no menu bar, HITL panel) exclusivamente para decisões que requerem julgamento humano.
**Because:** O usuário está com atenção dividida. Informação de status que não requer decisão não pode competir por atenção com HITL real. Ver `ux-identity.md` C1 e C5.
**Screens:** AgentCard, DashboardView, NSStatusItem
**Status:** codified

---

## Pattern: Ação Destrutiva Requer Confirmação

**When:** Ação irreversível ou de alto impacto: cancelar sessão, deletar task, encerrar agente.
**Then:** Alert de confirmação com descrição do efeito, botão destrutivo em vermelho, botão de cancelamento em destaque.
**Because:** C1 — ação é deliberada. Acidente em ação destrutiva tem custo alto (perda de contexto do agente, tokens gastos sem resultado).
**Screens:** AgentCard (cancel), TaskBacklog (delete task)
**Status:** proposed

---

## Pattern: Progressive Disclosure (Card → Detail)

**When:** Um agente tem estado rico (terminal output, evento history, sub-agents ativos).
**Then:** Card mostra o mínimo (status dot, nome da task, timer, token spend, fase atual). Detail (SpawnedAgentView ou AgentTerminalView) mostra o raw output. Transição via tap/double-click no card.
**Because:** C4 — não esconder, mas não forçar. Usuário decide quando quer profundidade.
**Screens:** AgentCard → SpawnedAgentView / AgentTerminalView
**Status:** codified

---

## Pattern: Status Dot de Agente

**When:** Qualquer view mostrando um agente.
**Then:** Dot colorido indica estado: verde (running), amarelo (waiting HITL), cinza (idle/done), vermelho (error). Sempre presente, nunca ausente, nunca piscando (exceto HITL pending).
**Because:** O usuário precisa avaliar o estado de N agentes em glance sem ler texto. Cor é o canal mais rápido. Piscagem é reservada para HITL porque é o único estado que pede ação.
**Screens:** AgentCard, DashboardView
**Status:** codified

---

## Pattern: Menu Bar como Sinaleiro

**When:** App está rodando em background.
**Then:** NSStatusItem mostra badge numérico apenas quando há HITL pendente. Sem HITL: ícone simples, sem badge. Clique no ícone: trazer o app para frente.
**Because:** C5 — menu bar não é workspace. Badge que aparece por motivos que não são HITL dilui o sinal e educa o usuário a ignorá-lo.
**Screens:** NSStatusItem
**Status:** codified

---

## Pattern: Criação via Sheet (não inline)

**When:** Usuário vai criar uma nova entidade: nova sessão de agente, nova task.
**Then:** Sheet modal sobrepõe o dashboard. Formulário focado, campo de texto em foco automático ao abrir. Dismiss com Escape ou botão Cancelar. Submit com Return ou botão primário.
**Because:** Criação é uma mudança de modo — requer atenção completa por 2-10 segundos. Inline editing no dashboard fragmentaria o layout e criaria ambiguidade entre "editando" e "monitorando".
**Screens:** NewAgentSheet, (futura) NewTaskSheet
**Status:** codified

---

## Pattern: Terminal como Inspeção

**When:** Usuário quer ver o output raw do agente.
**Then:** AgentTerminalView está disponível, mas não é a view default. Abrir via botão explícito no AgentCard. Fechar retorna ao dashboard. Não há ação disponível no terminal (apenas leitura + scroll).
**Because:** C2 — terminal é para entender, não para controlar. Se o usuário quer interagir com o agente, deve fazer isso via Claude Code diretamente.
**Screens:** AgentTerminalView, SpawnedAgentView
**Status:** codified

---

## Pattern: HITL como Interrupção Legítima

**When:** Agente envia pedido de aprovação (tool use confirmation, permissão de arquivo, etc.).
**Then:** NSPanel flutuante aparece sobre qualquer janela ativa. Badge no menu bar pisca. Notificação macOS enviada se app não estiver em foreground.
O painel tem duas ações: Aprovar (ação primária) e Rejeitar. Contexto completo do pedido visível sem scroll.
**Because:** HITL é o único estado que justifica quebrar o foco do usuário. O custo de não ver HITL a tempo (agente bloqueado, timeout) é maior do que o custo de interromper.
**Screens:** HITLPanelView, NSStatusItem
**Status:** codified

---

## Pattern: Quick Session sem Task

**When:** Usuário quer abrir um terminal ad-hoc sem criar uma ClaudeTask formal.
**Then:** QuickTerminalView e QuickAgentView disponíveis via ação secundária no dashboard (não via fluxo principal de "nova sessão"). Essas views não aparecem no TaskBacklog.
**Because:** Nem toda sessão é uma task gerenciável. Às vezes o dev quer rodar um comando rápido ou testar algo. Forçar criação de task para isso cria fricção desnecessária.
**Screens:** QuickTerminalView, QuickAgentView
**Status:** codified

---

## Pattern: Onboarding como Setup, não Tutorial

**When:** First-run: hooks não configurados.
**Then:** OnboardingView guia o usuário por um checklist de setup (instalar helper, configurar hooks, testar conexão).
Não mostra features do app — assume que o usuário já sabe o que quer. Desaparece após setup concluído e nunca mais aparece.
**Because:** O usuário chegou aqui com uma intenção específica (usar Claude Code com visibilidade). Tutorial de features é noise. O único blocker real é a infraestrutura (hooks, helper).
**Screens:** OnboardingView
**Status:** codified

---

## Pattern: Informação de Custo em Background

**When:** Token spend e custo estimado de uma sessão.
**Then:** Exibido no AgentCard como badge secundário (menor, menos destaque que status e nome). Formato: `$0.03` ou `3.2k tokens`. Nunca em notificação, nunca em alerta.
**Because:** Custo é informação de background — útil para calibrar uso, mas nunca urgente. Transformar custo em interrupção criaria ansiedade e não mudaria comportamento.
**Screens:** AgentCard
**Status:** codified

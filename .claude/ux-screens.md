# UX Screens: Claude Terminal

_Contrato de intenção por tela. Descreve o trabalho que o usuário faz aqui — não a implementação atual.
Gaps entre spec e código = drift a corrigir. Seção `Open` = decisões de UX ainda não tomadas._

---

## DashboardView

**Job:** Monitorar o estado de todos os agentes ativos em glance e identificar HITL pendente.
**Data:** Grid de AgentCards (um por agente/sessão ativa) + sidebar TaskBacklog.
**Entry:** Janela principal do app ao abrir; foco retorna aqui após fechar qualquer detail view.
**Exit:** AgentCard → SpawnedAgentView | AgentCard → AgentTerminalView | Botão "+" → NewAgentSheet.
**Open:**
- Layout quando não há agentes ativos: empty state com CTA para criar primeiro agente?
- Ordenação dos cards: por status (HITL primeiro)? por hora de criação? configurável?

---

## AgentCardView

**Job:** Representar uma sessão de agente com informação suficiente para saber se requer atenção.
**Data:** Status dot (cor), nome da task ou "[sem task]", CWD atual, timer desde início, fase da skill, token spend estimado, badge HITL se pendente.
**Entry:** Renderizado dentro do DashboardView grid.
**Exit:** Double-click → SpawnedAgentView | Botão terminal → AgentTerminalView | Botão ação (cancel, etc.).
**Open:**
- Quanto do output recente mostrar inline no card (último evento? última linha? nada)?
- Como mostrar sub-agents em background: badge numérico no card ou não mostrar?

---

## NewAgentSheet

**Job:** Criar uma nova sessão de agente associada a uma task (ou ad-hoc).
**Data:** Formulário: selecionar ClaudeTask (ou "sem task"), diretório de trabalho, comando inicial (opcional).
**Entry:** Botão "+" no DashboardView.
**Exit:** Submit → fecha sheet + novo AgentCard aparece no grid | Cancel → fecha sheet sem mudança.
**Open:**
- Campo de comando inicial: obrigatório ou opcional? Default = `claude`?
- Seleção de task: dropdown de tasks pendentes ou campo de texto livre?

---

## AgentTerminalView

**Job:** Inspecionar o output raw de um agente específico sem deixar o dashboard.
**Data:** PTY output do processo `claude`, scroll completo, sem input (read-only).
**Entry:** Botão terminal no AgentCard.
**Exit:** Fechar view → retorna ao DashboardView.
**Open:**
- Deveria permitir input? (decisão pendente — conflita com C2 de ux-identity.md)
- Busca no output (Cmd+F)? Útil mas aumenta complexidade.

---

## SpawnedAgentView

**Job:** Inspecionar o agente em janela dedicada para análise mais profunda.
**Data:** Terminal full-size do agente + metadata (status, tokens, eventos recentes).
**Entry:** Double-click no AgentCard no DashboardView.
**Exit:** Fechar janela → foco retorna ao DashboardView.
**Open:**
- Deve ser uma NSWindow separada ou um NavigationSplitView detail?
- Sidebar de eventos nesta view ou só terminal?

---

## QuickTerminalView

**Job:** Abrir um terminal zsh ad-hoc sem criar task ou sessão de agente.
**Data:** PTY interativo (zsh), sem associação a ClaudeTask.
**Entry:** Ação secundária no DashboardView (não via fluxo principal).
**Exit:** Fechar view.
**Open:**
- Deve aparecer no grid do Dashboard como card? (Provavelmente não — cria confusão com agentes reais.)
- CWD default: último usado? home? repo root?

---

## QuickAgentView

**Job:** Iniciar uma sessão `claude` ad-hoc sem criar task formal — para exploração rápida.
**Data:** PTY interativo rodando `claude` no diretório escolhido.
**Entry:** Ação secundária no DashboardView.
**Exit:** Fechar view.
**Open:**
- Deve criar um ClaudeAgent efêmero no SwiftData? Ou rodar completamente fora do modelo?
- Como distinguir visualmente de um AgentCard real no grid?

---

## TaskBacklogView

**Job:** Ver e gerenciar o backlog de ClaudeTasks — o trabalho planejado que ainda não tem agente.
**Data:** Lista de ClaudeTasks ordenada por prioridade/criação. Status: pending, in-progress, done.
**Entry:** Sidebar do DashboardView (sempre visível).
**Exit:** Selecionar task → contexto para criar novo agente | Botão "+" → criar nova task.
**Open:**
- Deve mostrar tasks done? (histórico) ou só pending/in-progress?
- Drag-to-reorder para priorização?
- Filtros por status?

---

## HITLPanelView

**Job:** Apresentar um pedido de aprovação de agente e capturar a decisão do usuário.
**Data:** Identificação do agente, descrição do pedido (tool use, permissão, confirmação), contexto suficiente para decidir. Ações: Aprovar / Rejeitar.
**Entry:** Push do agente via Unix domain socket → NSPanel aparece flutuante.
**Exit:** Aprovação → fecha panel + sinal enviado ao agente | Rejeição → idem com resposta negativa.
**Open:**
- Timeout: o que acontece se o usuário não responder em N segundos? (Auto-reject? Bloquear?)
- Múltiplos HITL simultâneos: queue ou um panel por agente?
- Input livre para o usuário customizar a resposta de aprovação?

---

## OnboardingView

**Job:** Guiar o usuário pelo setup de infraestrutura necessário para o app funcionar.
**Data:** Checklist: (1) instalar ClaudeTerminalHelper, (2) configurar hooks no Claude Code, (3) testar conexão via socket.
**Entry:** First-run (hooks não detectados) ou Settings → "Refazer setup".
**Exit:** Setup completo → DashboardView | Usuário fecha manualmente → DashboardView (com aviso de setup incompleto).
**Open:**
- Deve validar cada step antes de liberar o próximo? Ou checklist livre?
- Deep link para abrir as configurações corretas do Claude Code?

---

## SkillRegistryView

**Job:** Explorar e descobrir skills instaladas no Claude Code, entender o que cada uma faz.
**Data:** Lista de skills detectadas (lidas de `.claude/commands/`), nome, descrição curta, status (ativa/inativa).
**Entry:** Item no menu lateral ou Settings.
**Exit:** Fechar view.
**Open:**
- Read-only ou permite instalar/remover skills daqui?
- Link para abrir o arquivo `.md` da skill no editor?
- Filtro por projeto vs. global?

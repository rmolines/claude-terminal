# Discovery: session-cards-hitl-ui
_Gerado em: 2026-03-06_

## Problema real

O operador não consegue manter situational awareness de N sessões Claude Code concorrentes — múltiplas worktrees do mesmo projeto mais sessões de outros projetos — sem abrir terminais individualmente. Quando chega um HITL, ele precisa trocar de contexto para identificar qual sessão, o que ela está fazendo, e só então decidir. Com 4-8 sessões simultâneas, esse custo de atenção é cumulativo e degrada a supervisão: o operador começa a aprovar sem ler, ou deixa sessões paradas esperando input sem saber.

Os dois failure modes centrais confirmados pelo usuário:
- **A**: não saber qual sessão precisa de atenção sem varrer todos os terminais
- **B**: ter que trocar de janela/tab para aprovar HITL, perdendo o contexto da sessão que estava ativa
- **C** (secundário): contexto insuficiente na notificação para decidir — aprova tudo sem ler

## Usuário / contexto

Desenvolvedor solo rodando 4-8 sessões Claude Code simultâneas: tipicamente 4+ worktrees do mesmo projeto (ex: uma debugando, outra abrindo feature, outra fazendo explore/roadmap, outra close-feature) mais sessões de projetos diferentes em paralelo. Usa o app em desktop macOS, não remoto. Sente a dor especificamente quando tem sessões em fases muito diferentes e precisa manter o modelo mental de cada uma.

## Alternativas consideradas

| Opção | Por que não basta |
|---|---|
| Grid de terminais (iTerm/tmux) | Ruído visual excessivo; monitoring passivo impossível com N>3; exige ler cada terminal |
| Um terminal por vez (alternando) | Perda de contexto ao voltar para sessões "frias"; sessões HITL bloqueadas silenciosamente |
| Notificações do sistema para HITL | Sem contexto suficiente para decidir; treina a aprovar tudo sem ler |
| Terminal baseado em Ghostty (solo dev) | Produto ruim no geral; descartado por qualidade, não por conceito |
| ccmanager / Opcode / Claudia | Nenhum intercepta HITL nativamente; Opcode sem socket hook; ccmanager sem UI gráfica |

## Por que agora

O mecanismo de HITL (socket hook + PTY injection) já está funcionando e é único no mercado. O bloqueio para usar o app como plataforma primária de supervisão de múltiplos agentes é a camada de UI: sem identidade visual por sessão e sem fila de HITL, o operador cai de volta nos terminais para qualquer decisão. Resolver isso desbloqueia o caso de uso de 4-8 agentes concorrentes que é o principal diferencial do claude-terminal.

## Escopo da feature

### Dentro
- Session cards com identidade completa: projeto + worktree/branch + fase de workflow + status em tempo real
- Agrupamento visual por projeto com cards individuais por worktree/sessão dentro do projeto
- Tier de informação no card: (1) status pré-atentivo, (2) task identity + current tool — "o que é essa sessão", (3) last action/output expansível
- Fila visual de HITLs: múltiplas aprovações pendentes visíveis simultaneamente, sem modais empilhados
- Approve/Reject sem abrir o terminal — direto da fila de HITL
- Contexto suficiente no card HITL para decidir na maioria dos casos: tool name, args, risk surface
- "Ver terminal" como ação drill-down, não como superfície primária
- Funcional com 4-8 sessões simultâneas (mesmos projetos + cross-project)

### Fora (explícito)
- Histórico de sessões encerradas — apenas sessões ativas importam
- Mobile / push notifications — o problema é desktop, não remoto
- Mudanças no comportamento do terminal em si — só a camada de supervisão acima
- Triagem automática de HITL (GREEN/YELLOW/RED automático) — pode ser fase 2

## Critério de sucesso

- Com 6 sessões abertas (4 worktrees do mesmo projeto + 2 de outros projetos), o operador consegue identificar o que cada sessão está fazendo sem abrir nenhum terminal
- Uma aprovação HITL pode ser feita sem trocar de janela e sem abrir o terminal, nos casos em que o contexto mostrado é suficiente para decidir
- O terminal se mantém acessível como drill-down quando o contexto do card não é suficiente

## Riscos identificados

- **Actor → Observable sync silencioso**: mutations no `SessionManager` actor não notificam `@Observable SessionStore` automaticamente — padrão `Task { @MainActor in SessionStore.shared.update(session) }` deve ser seguido em todos os novos event handlers, senão views ficam stale sem erro
- **NSPanel geometry + SwiftUI**: `NSHostingView.rootView =` enquanto painel visível causa crash em macOS 26 — padrão `@Observable HITLPanelState` (já validado) deve ser mantido para a fila; redimensionamento do painel com N cards precisa de `frame(maxWidth:)` + `@AppStorage` para persistir geometria
- **Task identity source**: `currentActivity` é uma string genérica populada a partir de eventos — para o Tier 2 ("o que é essa sessão"), pode ser necessário adicionar `taskDescription` ao `IPCProtocol` ou derivar de forma mais estruturada do `detail` do evento
- **Risk surface por heurísticas**: pattern matching local (`rm -rf`, `git push --force`) tem false positives e false negatives — deve ser isolado em `RiskSurfaceComputer` para refactoring futuro, e calibrado com cautela para não treinar ignorar os warnings
- **Timer cascades em N cards**: timers individuais por card (para elapsed time) escalam mal com 8+ sessões — usar `TimelineView(.periodic(from: .now, by: 1.0))` no parent view

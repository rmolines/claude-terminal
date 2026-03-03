# UX Identity: Claude Terminal

_Spec viva. Muda raramente — só quando o modelo mental do app muda, não quando a implementação muda._

## O que é (modelo mental)

Claude Terminal é o **painel de controle de missão** para uma squad de agentes Claude Code rodando
em paralelo. A metáfora operacional: um desenvolvedor solo com múltiplos agentes trabalhando
simultaneamente precisa de uma "sala de controle" — não de mais terminais empilhados.

O app não executa trabalho. Ele torna o trabalho dos agentes **legível, monitorável e interrompível**
quando necessário.

## Para quem e em que contexto

Dev solo (ou pequeno time) que usa Claude Code como força multiplicadora. O usuário está
**focado em trabalho próprio** enquanto agentes executam tarefas em paralelo. O contexto de uso
é de atenção dividida — o app compete com código, browser, comunicação.

Isso tem uma consequência de design: o app precisa ser **periférico por default** e
**central por exceção** (quando há HITL pendente ou falha crítica).

## Hierarquia de atenção

1. **HITL pendente** — o único motivo legítimo para interromper o usuário
2. **Status de cada agente** — o que está acontecendo, sem precisar abrir o terminal
3. **Tokens e custo** — informação de background, nunca urgente
4. **Histórico e tasks** — contexto passado, acessado intencionalmente

Tudo que não é HITL deve ser observável sem mudar o foco. Tudo que é HITL pode (e deve)
interromper.

## Princípios como constraints (não aspirações)

**C1 — Status é passivo, ação é deliberada.**
Badges, dots e contadores atualizam silenciosamente. Ações (criar sessão, cancelar, aprovar HITL)
exigem intent explícito do usuário — nunca acontecem por hover ou acidente.

**C2 — O terminal é para inspeção, não para trabalho.**
O PTY existe para o usuário entender _o que o agente está fazendo_, não para interagir com o
agente diretamente. Se o usuário quer controlar o agente, ele usa Claude Code — não este app.

**C3 — Uma tela, uma decisão.**
Cada view tem um job primário. Se o usuário não sabe _o que fazer aqui_, o design falhou.
Exceções precisam de aprovação explícita de design antes de serem implementadas.

**C4 — Não esconder informação, mas não forçar atenção.**
O usuário pode querer ver tokens, ver o terminal completo, ver o histórico de eventos — mas
essas views são opt-in. O estado default mostra só o mínimo para rastrear o progresso.

**C5 — Menu bar como sinaleiro, não como workspace.**
O status item no menu bar tem um job: indicar se há HITL pendente (e quantos). Não é um
mini-dashboard. Clicar nele abre o app principal — não um popover com funcionalidade duplicada.

## O que este app NÃO é

- **Não é um terminal emulator.** SwiftTerm é um detalhe de implementação, não o produto.
- **Não é um task manager.** Tasks são criadas e gerenciadas por Claude Code e suas skills.
  O app mostra tasks; não cria fluxo de criação de tasks complexo.
- **Não é um editor.** Nenhuma view permite editar código, configuração ou prompts dos agentes.
- **Não é um launcher de agentes genérico.** É especializado para Claude Code — não para
  agentes arbitrários ou outros LLMs.
- **Não é um app de notificações.** Notificações existem apenas para HITL. Status de progresso
  não gera notificação — o usuário consulta o dashboard quando quer.

# Discovery: agent-card-ui
_Gerado em: 2026-03-02_

## Problema real
A UI atual (lista + split view com terminal raw) não escala bem para múltiplos agentes simultâneos.
O usuário precisa alternar entre itens da lista para ver o que cada agente está fazendo,
e responder pedidos HITL exige abrir o painel de terminal.

## Usuário / contexto
Dev solo rodando 3-8 agentes Claude Code em paralelo via iTerm.
Quer visão panorâmica de todos os agentes e responder HITL sem quebrar o foco.

## Alternativas consideradas
| Opção | Por que não basta |
|---|---|
| Lista atual + split view | Não mostra múltiplos agentes ao mesmo tempo; terminal raw é barulhento |
| Dashboard tabular | Não suporta interação inline (HITL) |

## Por que agora
Usuário está ativamente usando o app com 4+ agentes e a UI atual é o principal ponto de atrito.

## Escopo da feature
### Dentro
- Grid adaptativo de cards (colunas ajustam ao tamanho da janela)
- Card de tamanho fixo: status dot, working dir, contexto derivado de hooks (ex: "Editing SessionManager.swift", "Running /ship-feature"), timer, tokens
- Contexto de sessão derivado automaticamente dos hooks: último evento relevante (tool calls, edits, comandos) vira "resumo" do card — sem input manual
- Estado interativo inline no card: Allow/Deny, Yes/No, text input curto
- Terminal raw como popover/overlay do card (abre ao clicar)

### Fora (explícito)
- Redesign do backlog/task list
- Notificações push / menu bar badge (já existe)
- Histórico de mensagens scrollável dentro do card (só último evento)
- Resize manual de cards

## Critério de sucesso
- Com 4+ agentes ativos, todos visíveis simultaneamente sem scroll
- Responder um HITL (allow/deny/yes/no) sem abrir o terminal raw
- Terminal raw ainda acessível via clique no card

## Riscos identificados
- Grid layout em SwiftUI com tamanho dinâmico de colunas pode ser complexo com LazyVGrid
- Popover sobre card precisa não conflitar com o clique de seleção do card
- Estado interativo inline requer parsing do tipo de pedido HITL para renderizar UI correta

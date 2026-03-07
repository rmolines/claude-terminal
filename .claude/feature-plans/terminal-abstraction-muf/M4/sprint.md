# Sprint M4 — HITL Redesign: todas as interações happy path

_Gerado em: 2026-03-06_

> Status ao vivo: use /project-compass. Este arquivo é readonly após criação.

## Milestone

**Objetivo:** HITL Redesign — todas as interações happy path com o agente têm representação no app
**Critério de done:** Dev passa 5 dias úteis sem abrir terminal para interagir com agente ativo. Todas as interações happy path do Claude Code têm representação no app.

## MUF deste milestone

- **Ação que o dev para de fazer no terminal:** responder perguntas do Claude, dar steering mid-run, confirmar planos, aprovar/rejeitar tools com contexto suficiente para decidir sem abrir o PTY
- **Critério de verificação:** 5 dias úteis sem abrir terminal para interagir com agente ativo
- **Features mínimas para atingir o MUF:** `agent-message-input`, `hitl-rich-context-card`
- **Features enabler** (infra que outra feature precisa): nenhuma — PTY injection, HITLQueueView e WorkSessionRowView já existem do worksession-panel (#66)
- **Features enhancement** (valor incremental, não bloqueia MUF): `hitl-reject-with-reason`, `agent-reply-detection`

## Contexto herdado

O `worksession-panel` (#66) entregou:
- Sessions tab com `WorkSession` runtime (worktree + AgentSession + KanbanFeature) ordenada por urgência
- Inline HITL Approve/Reject em `WorkSessionRowView` + supressão do floating panel
- PTY injection via `TerminalRegistry.sendInput(_:forCwd:)` já funcionando

## Features (ordem de execução)

| # | Feature | Slug | Deps | Effort | Status | MUF-critical |
|---|---------|------|------|--------|--------|--------------|
| 1 | "Message agent" input no Sessions tab — cobre resposta a perguntas, steering mid-run e confirmação de plano via injeção no PTY | `agent-message-input` | — | médio | pending | sim |
| 2 | PermissionRequest card com contexto rico: comando Bash exato, path de arquivo, badge por tipo de tool | `hitl-rich-context-card` | — | médio | pending | sim |
| 3 | Reject + instrução: após rejeitar, campo opcional "Por quê?" injetado no PTY | `hitl-reject-with-reason` | — | baixo | pending | não |
| 4 | Detecção de "aguardando resposta" via padrões do PTY output → status visual distinto de RUNNING | `agent-reply-detection` | `agent-message-input` | alto | pending | não |

## Grafo de dependências

```text
agent-message-input → agent-reply-detection
hitl-rich-context-card  (independente)
hitl-reject-with-reason (independente)
```

## Nota de design

Os itens 2, 3 e 4 do roadmap (resposta a perguntas, steering mid-run, confirmação de plano) convergem em `agent-message-input` — a implementação é a mesma: input field no `WorkSessionRowView` que injeta texto no PTY da sessão via `TerminalRegistry`. A detecção de "Claude aguardando" é enhancement separado (`agent-reply-detection`), não bloqueia o MUF.

## Critério de granularidade

Uma feature está bem-scoped quando:
- Toca 1–3 arquivos principais
- Tem um "demonstrável" claro (tela que aparece, teste que passa, endpoint que responde)
- Pode ser implementada em 1 sessão de Claude Code sem `/clear` intermediário
- Nome kebab-case descreve o QUE, não o POR QUE

## Próximo passo

```text
/start-feature agent-message-input
```

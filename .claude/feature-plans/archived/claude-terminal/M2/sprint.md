# Sprint M2 — Mission Control
_Gerado em: 2026-03-01_

## Milestone

**Objetivo:** Substituir as abas de terminal empilhadas no workflow diário.

**Critério de done:** O criador não abre Warp/iTerm para gerenciar a squad — só para sessões fora do app.

## Features (ordem de execução)

| # | Feature | Slug | Deps | Esforço | Status |
|---|---------|------|------|---------|--------|
| 1 | Setup ModelContainer + TaskBacklogView com CRUD completo (list, create, delete) via SwiftData | `task-backlog-persistence` | — | baixo | ✅ done |
| 2 | Terminal embedado no dashboard como detail pane toggleável por agente | `terminal-per-agent-ui` | — | médio | ✅ done |
| 3 | Botão "New Agent": seleciona task do backlog → cria worktree → spawna processo Claude Code | `agent-spawn-ui` | `task-backlog-persistence` | médio | ✅ done |
| 4 | Dispatch da skill correta (start-feature/fix) no worktree ao criar/associar task | `task-orchestration` | `agent-spawn-ui` | médio | ✅ done (PR #8) |

## Grafo de dependências

```
task-backlog-persistence → agent-spawn-ui → task-orchestration
terminal-per-agent-ui (independente)
```

## Estado do scaffold (o que já existe)

| Componente | Estado |
|---|---|
| `ClaudeTask` + `ClaudeAgent` (@Model) | Definidos — ModelContainer configurado via `.modelContainer(for:)` na `WindowGroup` |
| `TaskBacklogView` | Implementado — CRUD completo com `@Query`, inline create, swipe-to-delete |
| `TerminalViewRepresentable` | Implementado com isolation de queue — embedado em `AgentTerminalView` |
| `WorktreeManager` | Implementado e pronto para uso |
| `SessionManager` + `HookIPCServer` | Implementados — suportam N sessões simultâneas |
| `DashboardView` | Funcional — mostra sessões via hook events, sem SwiftData |

## Critério de granularidade

Uma feature está bem-scoped quando:

- Toca 1–3 arquivos principais
- Tem um "demonstrável" claro (tela que aparece, teste que passa, endpoint que responde)
- Pode ser implementada em 1 sessão de Claude Code sem `/clear` intermediário
- Nome kebab-case descreve o QUÊ, não o PORQUÊ

## Status do Milestone

**M2 COMPLETO** — todas as features entregues.

## Próximo passo

```
/start-milestone M3
```

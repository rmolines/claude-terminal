# Sprint M1 — Agente vivo
_Gerado em: 2026-03-01_

## Milestone

**Objetivo:** Usar o app para gerenciar 1 agente real por 5 dias úteis.

**Critério de done:** 5 dias úteis consecutivos gerenciando agentes reais sem abrir o terminal
para verificar status ou aprovar HITL.

## Features (ordem de execução)

| # | Feature | Slug | Deps | Esforço | Status |
|---|---------|------|------|---------|--------|
| 1 | Hook pipeline end-to-end + IPC socket funcionais | `hook-pipeline` | — | baixo | ✅ completed (PR #3) |
| 2 | Dashboard: fase atual, elapsed timer, sub-agent badge | `dashboard-status` | `hook-pipeline` | baixo | ✅ completed (PR #4) |
| 3 | Dashboard: tokens consumidos + custo estimado | `dashboard-tokens` | `dashboard-status` | baixo | ✅ completed (PR #5) |
| 4 | HITL: badge no NSStatusItem + notificação com Approve/Reject | `hitl-panel` | `hook-pipeline` | médio | ✅ completed (PR #3) |

## Grafo de dependências

```
hook-pipeline → dashboard-status → dashboard-tokens (✅)
hook-pipeline → hitl-panel (✅)
```

## Status do Milestone

**M1 COMPLETO** — todas as features entregues.

## Critério de granularidade

Uma feature está bem-scoped quando:

- Toca 1–3 arquivos principais
- Tem um "demonstrável" claro (tela que aparece, teste que passa, endpoint que responde)
- Pode ser implementada em 1 sessão de Claude Code sem `/clear` intermediário
- Nome kebab-case descreve o QUÊ, não o PORQUÊ

## Próximo passo

```
/start-milestone M2
```

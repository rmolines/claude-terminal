# test/index — Available test skills for Claude Terminal

Run from inside a Claude session managed by the app (Sessions tab).

## Skills

| Skill | Invocation | Tests |
|---|---|---|
| HITL — Bash | `/test:hitl-bash` | PermissionRequest + TUI dialog + Approve/Reject, badge "Bash" |
| HITL — Write | `/test:hitl-write` | Mesmo fluxo, badge "Write" |
| Mid-run question | `/test:question` | Message-input PTY injection (agente espera reply) |
| Long run | `/test:long-run` | bashToolUse × N + 1 HITL mid-run + stopped |
| Immediate stop | `/test:stop` | .completed badge + token usage |

## Ordem recomendada

1. `/test:stop` — baseline de lifecycle
2. `/test:hitl-bash` — Approve; rodar de novo e Reject
3. `/test:hitl-write` — verificar badge "Write" vs "Bash"
4. `/test:long-run` — sequência multi-evento (aprovar o sleep 2)
5. `/test:question` — message-input injection

## Preconditions

- App rodando, helper registrado em `~/.claude/settings.json`
- Sessão spawned pelo app (não iTerm) — `CLAUDE_TERMINAL_MANAGED=1`
- `Bash(git *)` pré-aprovado; demais Bash → HITL

# /handover

Generate a HANDOVER.md entry summarizing this Claude Code session and prepend it to `HANDOVER.md`.

## Format

```markdown
## [YYYY-MM-DD] — <session title (1 line)>

**What was done:**
- [bullet — specific action or decision]
- [bullet]

**Architectural decisions:**
- [decision and rationale — omit if none]

**Files modified:**
- `path/to/file` — [why]

**Open threads / next steps:**
- [anything left incomplete or that the next session should pick up]
```

## Rules

- Title should be a concise description of the session's main outcome
- Be specific — "fixed lint errors in ci.yml" not "improved CI"
- Architectural decisions: only include if a non-obvious choice was made
- Open threads: be honest about what's incomplete; this is for the next agent/session
- Keep the entry to <20 lines

## Execution

1. Summarize this session based on the conversation history
2. Prepend the entry to `HANDOVER.md` (newest at top)
3. Confirm with the file path and entry summary

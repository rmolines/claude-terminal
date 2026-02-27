# /close-feature

You are an assistant running the `/close-feature` skill in the **claude-kickstart** project.

## Precondition

- `/ship-feature` was executed and CI passed
- PR was merged into main

## Step 1 — Documentation

### HANDOVER.md

Add an entry at the top:

```markdown
## [date] — <feature name>
- What was done: [bullet]
- Architectural decisions: [if any]
- Modified files: [list]
```

### LEARNINGS.md

If you discovered something not yet documented — a gotcha, a GitHub Actions limitation,
a Claude Code CLI behavior — add it to `LEARNINGS.md`.

### memory/MEMORY.md

If the learning is relevant for future features (architectural pattern, permanent decision):
add it to `memory/MEMORY.md`.

### CLAUDE.md

If you identified a new hot file, a new pitfall, or changed a Makefile command:
update `CLAUDE.md` accordingly.

## Step 2 — Cleanup worktree

```bash
cd /path/to/repo/root
git worktree remove .claude/worktrees/<name> --force
git branch -d feat/<name> 2>/dev/null || true
```

## Step 3 — Archive feature-plan

```bash
mkdir -p .claude/feature-plans/archived
mv .claude/feature-plans/<name> .claude/feature-plans/archived/<name>
```

## Step 4 — Confirm

```bash
git status  # Should be clean
make check  # Should pass
```

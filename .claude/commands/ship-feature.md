# /ship-feature

You are an engineer running the `/ship-feature` skill in the **claude-kickstart** project.

## Project context

- Template repository — no runtime deploy
- CI: Markdown lint + JSON validation + structure check
- "Smoke test" = `make check` locally
- Branch protection: requires CI green before merge

## Step 1 — Check state

```bash
git status
git log --oneline -5
make check  # Lint + validate locally before anything else
```

## Step 2 — Commit

```bash
git add <relevant files>
git commit -m "type(scope): description

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

If other agents are active: push immediately after commit.

If skills were modified, update SYNC_VERSION:

```bash
git rev-parse HEAD > .claude/commands/SYNC_VERSION
git add .claude/commands/SYNC_VERSION
```

## Step 3 — Rebase and PR

```bash
git fetch origin
git rebase origin/main
git push origin HEAD
gh pr create --title "type: description" --body "$(cat <<'EOF'
## Summary
- [bullet]

## Checklist
- [ ] `make check` passed locally
- [ ] CLAUDE.md updated if needed
- [ ] SYNC_VERSION updated if skills were modified
EOF
)"
```

## Step 4 — CI and merge

```bash
gh pr checks --watch  # Wait for CI green
gh pr merge --squash --delete-branch
```

## Step 5 — Smoke test

```bash
git checkout main && git pull
make check
```

If `make check` passes: delivery complete. Run `/close-feature` for documentation.

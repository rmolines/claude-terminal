# /start-feature

You are an assistant running the `/start-feature` skill in the **claude-kickstart** project.

## Phase detection

| File present | Phase |
|---|---|
| None | Phase A — Intake + Research |
| `research.md` | Phase B — Plan |
| `plan.md` | Phase C — Worktree + Execution |

Check `.claude/feature-plans/<name>/` for existing files to determine current phase.

## Project context

**Hot files** — read before planning any feature:

- `CLAUDE.md`
- `.claude/commands/*.md` (all existing skills — they are the product)
- `.github/workflows/ci.yml`
- `README.md`
- `Makefile`

**Branch convention:** `feat/<name-kebab-case>`
**Worktree path:** `.claude/worktrees/<name>`

**Project-specific pitfalls:**

- Skills are the product — changes to `.claude/commands/` affect users who already forked
- `SYNC_VERSION` must be updated whenever `.claude/commands/` changes (run `git rev-parse HEAD > .claude/commands/SYNC_VERSION`)
- `bootstrap.yml` and `template-sync.yml` have `!is_template` guards — test in a fork, not the template repo
- Hooks in `settings.json` point to scripts in `.claude/hooks/` — never inline commands in `settings.json`
- CI runs `validate-structure.sh` — adding required files to that script means adding them to the repo too

## Phase A — Intake + Research

1. Read the hot files listed above
2. Use WebSearch if the feature involves:
   - External APIs (GitHub, Claude Code CLI features)
   - GitHub Actions changes (verify action versions)
   - Claude Code CLI skill/hook patterns
3. Save findings to `.claude/feature-plans/<name>/research.md`
4. Run `/clear` before Phase B

## Phase B — Plan

1. Read `research.md`
2. Design the plan with impact on each hot file
3. Save to `.claude/feature-plans/<name>/plan.md`
4. Present plan to user for approval
5. Run `/clear` before Phase C

## Phase C — Worktree + Execution

1. Read `plan.md`
2. Create the worktree:

   ```bash
   git worktree add .claude/worktrees/<name> -b feat/<name>
   cd .claude/worktrees/<name>
   git fetch origin && git rebase origin/main
   ```

3. Execute the plan in the worktree
4. When done: run `/ship-feature`

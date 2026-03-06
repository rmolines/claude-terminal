# test/long-run

Test: multi-fase com bashToolUse events, 1 HITL mid-run, e stopped.

Execute EXACTLY these steps in order:

1. Say: "Phase 1 starting."
2. Run: `git log --oneline -5`   ← auto-approved (git *)
3. Run: `git status`              ← auto-approved (git *)
4. Say: "Phase 1 complete. Phase 2 starting."
5. Run: `sleep 2`                 ← TRIGGERS HITL — approve to continue
6. Say: "Phase 2 complete. Phase 3 starting."
7. Run: `git diff --stat HEAD~1`  ← auto-approved (git *)
8. Run: `git branch -a`           ← auto-approved (git *)
9. Say: "Phase 3 complete. All done."
10. Stop.

**Observe in app:** activity line atualiza com cada git cmd → HITL mid-run no step 5 → token badge cresce → .completed no final.

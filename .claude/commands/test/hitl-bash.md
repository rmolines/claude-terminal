# test/hitl-bash

Test: PermissionRequest hook para Bash + TUI dialog + Approve/Reject.

Execute EXACTLY these steps. Do not deviate.

1. Say: "Step 1: requesting Bash permission now."
2. Run this exact Bash command: `echo "hitl-bash-$(date +%s)" > /tmp/claude-terminal-hitl-test.txt`
3. After the command resolves, say: "Step 2 done. Result: [approved / rejected]."
4. Stop. Do not run any further commands.

**Observe in app:** agent blocked → HITL card com toolName "Bash" e o comando como detail → Approve/Reject → running.

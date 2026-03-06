# test/hitl-write

Test: PermissionRequest hook para Write + badge "Write" no HITL card.

Execute EXACTLY these steps. Do not deviate.

1. Say: "Step 1: requesting Write permission now."
2. Write the text `test` to `/tmp/claude-terminal-write-test.txt`.
3. After the Write resolves, say: "Step 2 done. Result: [approved / rejected]."
4. Stop. Do not run any further commands or tools.

**Observe in app:** mesmo fluxo do hitl-bash, mas toolName badge mostra "Write".

# /ship-feature

Entrega uma feature do claude-terminal: build, tests, PR.

O argumento é o nome da feature (mesmo nome usado no `/start-feature`).

---

## Pré-condições

- Worktree ativo em `.claude/worktrees/<nome>`
- Todos os arquivos commitados no branch `feature/<nome>`

---

## Passo 0 — Verificar Xcode MCP

```bash
# Claude Code stores MCP servers in ~/.claude.json (user scope) or project .mcp.json
python3 -c "
import json, sys, os
home = os.path.expanduser('~')
for path in [os.path.join(home, '.claude.json'), os.path.join(home, '.claude', 'settings.json')]:
    try:
        d = json.load(open(path))
        if 'xcode' in d.get('mcpServers', {}):
            sys.exit(0)
    except Exception:
        pass
sys.exit(1)
" 2>/dev/null
```

Se retornar erro (exit ≠ 0): **parar imediatamente** e instruir o usuário:

```
❌ Xcode MCP não está registrado. Execute primeiro:

    make xcode-mcp

Depois reabra o Package.swift no Xcode e rode /ship-feature novamente.
```

---

## Passo 1 — Build

Usar a ferramenta **`BuildProject`** do Xcode MCP.

Se falhar: parar, reportar os erros estruturados, não continuar.

---

## Passo 2 — Testes

Usar a ferramenta **`RunAllTests`** do Xcode MCP.

Se falhar: parar, reportar os testes com falha, não criar PR.

---

## Passo 3 — Checklist manual antes do PR

- [ ] Schema SwiftData mudou? → `VersionedSchema` foi atualizado com `MigrationStage`?
- [ ] `IPCProtocol.swift` mudou? → ClaudeTerminal E ClaudeTerminalHelper compilam com a mesma versão?
- [ ] Entitlements mudaram? → `app.entitlements` e `helper.entitlements` estão corretos?
- [ ] Novo código processa input de hook? → allowlist aplicada?
- [ ] Novo código executa processo filho? → env vars filtrados?
- [ ] Nova dependência SPM adicionada? → `Package.resolved` foi atualizado (committed)?

---

## Passo 4 — Commit final e PR

```bash
cd .claude/worktrees/<nome>

# Push do branch
git push origin feature/<nome>

# Criar PR
gh pr create \
  --title "<título conciso em inglês>" \
  --body "$(cat <<'EOF'
## Summary
- <o que muda e por quê>
- <targets afetados: ClaudeTerminal / ClaudeTerminalHelper / Shared>

## Test plan
- [ ] Build passa sem warnings novos (`BuildProject` ou `swift build`)
- [ ] Testes passam (`RunAllTests` ou `swift test`)
- [ ] Testado manualmente: <descrever o fluxo testado>

## Schema / Protocol changes
<"None" ou descrever a MigrationStage adicionada / mudança no IPCProtocol>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Critério de "done"

- Build e testes passam sem erros (`BuildProject`/`RunAllTests` se Xcode MCP disponível, `swift build`/`swift test` como fallback)
- CI verde no PR (lint + build + test)
- PR criado com descrição adequada
- Nenhum item do checklist manual em aberto

# /ship-feature

Entrega uma feature do claude-terminal: build, tests, PR.

O argumento é o nome da feature (mesmo nome usado no `/start-feature`).

---

## Pré-condições

- Worktree ativo em `.claude/worktrees/<nome>`
- Todos os arquivos commitados no branch `feature/<nome>`

---

## Passo 1 — Build de todos os targets

```bash
cd .claude/worktrees/<nome>

swift build --configuration debug 2>&1
```

Se falhar: parar, reportar o erro completo, não continuar.

---

## Passo 2 — Testes

```bash
swift test --configuration debug 2>&1
```

Se falhar: parar, reportar, não criar PR.

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
- [ ] `swift build` passa sem warnings novos
- [ ] `swift test` passa
- [ ] Testado manualmente: <descrever o fluxo testado>

## Schema / Protocol changes
<"None" ou descrever a MigrationStage adicionada / mudança no IPCProtocol>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Critério de "done"

- `swift build` e `swift test` passam sem erros
- CI verde no PR (lint + build + test)
- PR criado com descrição adequada
- Nenhum item do checklist manual em aberto

# /start-feature

Inicia uma nova feature no claude-terminal com worktree isolado.

O argumento é o nome da feature (kebab-case). Ex: `/start-feature hitl-notifications`

---

## Fase 0 — Detectar a feature a iniciar

**Se `$ARGUMENTS` foi fornecido**, use esse valor como nome da feature e pule para a Fase A.

**Se `$ARGUMENTS` está vazio:**

1. Verifique se existe `sprint.md` em `.claude/feature-plans/claude-terminal/<milestone>/sprint.md` (gerado pelo `/start-milestone`)
   - Se existir: leia e identifique o primeiro item `- [ ]` sem branch `feature/` correspondente em `git branch -a`
2. Se não houver `sprint.md`, leia `.claude/feature-plans/claude-terminal/roadmap.md` e encontre o primeiro item `- [ ]` em `### M1` sem branch `feature/` correspondente
3. Derive o nome kebab-case a partir do texto do item (ex: "Dashboard de status dos agentes" → `agent-status-dashboard`)
4. Apresente ao usuário:

```text
Nenhuma feature especificada. Encontrei no <sprint.md|roadmap.md>:

Próxima feature: "<texto do item>"
Slug sugerido: <slug-kebab-case>

Confirma? (ou informe outro nome)
```

Aguarde confirmação antes de continuar.

---

## Fase A — Contexto obrigatório (ler ANTES de qualquer planejamento)

Leia estes arquivos na ordem — sem exceção:

1. `CLAUDE.md` — visão geral, stack, armadilhas do projeto
2. `Shared/IPCProtocol.swift` — contrato IPC app ↔ helper
3. `ClaudeTerminal/Services/SessionManager.swift` — actor central de estado
4. `ClaudeTerminal/Models/ClaudeTask.swift` + `ClaudeAgent.swift` — schema SwiftData
5. `ClaudeTerminalHelper/main.swift` — entry point do helper
6. `Package.swift` — targets e dependências

Se a feature tocar em release/signing/entitlements, leia também:
- `.github/workflows/release.yml`
- `app.entitlements` + `helper.entitlements`

---

## Fase B — Checklist de infraestrutura (verificar antes de propor implementação)

- [ ] A feature muda o schema SwiftData? → adicionar `MigrationStage` no `VersionedSchema` antes de qualquer outra mudança
- [ ] A feature muda `Shared/IPCProtocol.swift`? → app E helper precisam ser atualizados juntos no mesmo PR
- [ ] A feature adiciona entitlement? → verificar compatibilidade com notarização (evitar `temporary-exception.*`)
- [ ] A feature cria nova instância de `LocalProcessTerminalView`? → garantir `DispatchQueue` separada por instância
- [ ] A feature executa processo filho? → filtrar env vars (allowlist: `PATH`, `HOME`, `TERM`)
- [ ] A feature processa input de hook? → validar via allowlist antes de qualquer execução (CVE-2025-59536)
- [ ] A feature adiciona dependência SPM? → atualizar `Package.swift` e confirmar que CI continua verde

---

## Fase C — Worktree

```bash
FEATURE="<nome-da-feature>"
BRANCH="feature/${FEATURE}"
WORKTREE_PATH=".claude/worktrees/${FEATURE}"

git fetch origin
git worktree add -b "$BRANCH" "$WORKTREE_PATH" origin/main
cd "$WORKTREE_PATH"
```

> Se o Xcode estiver aberto com o projeto, feche e reabra após criar o worktree.

---

## Fase D — Plano

Com o contexto lido e o checklist verificado, use o modo `/plan` para propor a implementação.

O plano deve especificar explicitamente:
- Arquivos a criar ou modificar
- Targets afetados (ClaudeTerminal / ClaudeTerminalHelper / Shared)
- Se há mudança de schema SwiftData (e a migration stage correspondente)
- Se há mudança no IPCProtocol (e os dois targets que precisam ser atualizados)

---

## Após implementar

Antes de rodar `/ship-feature`, rode `/validate` para verificar se o que foi implementado ainda resolve o problema original definido nesta Fase D.

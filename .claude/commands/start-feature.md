# /start-feature

Inicia uma nova feature no claude-terminal com worktree isolado.

O argumento é o nome da feature (kebab-case). Ex: `/start-feature hitl-notifications`

---

## Fase 0 — Detectar a feature e o milestone

**Se `$ARGUMENTS` foi fornecido**, use esse valor como slug da feature e pule para a Fase 0b.

**Se `$ARGUMENTS` está vazio:**

1. Verifique se existe `sprint.md` em `.claude/feature-plans/claude-terminal/<milestone>/sprint.md`
   - Se existir: leia e identifique o primeiro item com status `pending` sem branch `feature/` correspondente em `git branch -a`
2. Se não houver `sprint.md`, leia `.claude/feature-plans/claude-terminal/roadmap.md` e encontre o primeiro item `- [ ]` em `### M1` sem branch `feature/` correspondente
3. Derive o nome kebab-case a partir do texto do item (ex: "Dispatch da skill correta" → `task-orchestration`)
4. Apresente ao usuário:

```text
Nenhuma feature especificada. Encontrei no <sprint.md|roadmap.md>:

Próxima feature: "<texto do item>"
Slug sugerido: <slug-kebab-case>

Confirma? (ou informe outro nome)
```

Aguarde confirmação antes de continuar.

### Fase 0b — Detectar o milestone da feature

Para determinar onde salvar o `plan.md`:

1. Varrer todos os arquivos `sprint.md` em `.claude/feature-plans/claude-terminal/M*/sprint.md`
2. Identificar qual sprint.md contém o slug da feature
3. Extrair o milestone do path (ex: `M2/sprint.md` → milestone = `M2`)
4. Se o slug não aparecer em nenhum sprint.md: é uma feature ad-hoc → milestone = `adhoc`

---

## Fase A — Contexto obrigatório (ler ANTES de qualquer planejamento)

Leia estes arquivos em paralelo — sem exceção:

1. `CLAUDE.md` — visão geral, stack, armadilhas do projeto
2. `.claude/feature-plans/claude-terminal/workflow.md` — mapa de skills e hierarquia de diretórios
3. `Shared/IPCProtocol.swift` — contrato IPC app ↔ helper
4. `ClaudeTerminal/Services/SessionManager.swift` — actor central de estado
5. `ClaudeTerminal/Models/ClaudeTask.swift` + `ClaudeAgent.swift` — schema SwiftData
6. `ClaudeTerminalHelper/main.swift` — entry point do helper
7. `Package.swift` — targets e dependências

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

Com o contexto lido e o checklist verificado, use o modo plan (`/plan`) para propor a implementação.

O plano deve especificar explicitamente:
- Arquivos a criar ou modificar
- Targets afetados (ClaudeTerminal / ClaudeTerminalHelper / Shared)
- Se há mudança de schema SwiftData (e a migration stage correspondente)
- Se há mudança no IPCProtocol (e os dois targets que precisam ser atualizados)

### Após aprovação do plano — salvar plan.md

Após o usuário aprovar o plano, **escrever obrigatoriamente**:

```
.claude/feature-plans/claude-terminal/<milestone>/<feature>/plan.md
```

Exemplos:
- Feature `task-orchestration` do `M2` → `.claude/feature-plans/claude-terminal/M2/task-orchestration/plan.md`
- Feature ad-hoc `minha-feature` → `.claude/feature-plans/claude-terminal/adhoc/minha-feature/plan.md`

O `plan.md` deve conter:
- `## Problema` — o problema original que a feature resolve (1-3 frases)
- `## Solução` — a abordagem aprovada
- `## Passos de execução` — lista ordenada dos itens do plano

Esse arquivo é lido pelo `/validate` para verificar alinhamento durante a implementação.

---

## Após implementar

Antes de rodar `/ship-feature`, rode `/validate` para verificar se o que foi implementado ainda resolve o problema original definido nesta Fase D.

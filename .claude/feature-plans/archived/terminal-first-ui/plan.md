# Plan: terminal-first-ui

## Problema

O painel atual (DashboardView) tem muita funcionalidade — sidebar de tasks, grid de
agent cards, onboarding, skill registry, múltiplos tipos de janela. A única coisa que
o usuário precisa agora é: abrir o app e ter um terminal rodando `claude` inline no
painel principal, sem fricção e sem ruído visual.

## Decisões tomadas

- App abre **direto no terminal** — sem empty state, sem launcher
- Terminal inicia em `~` (home); botão no header muda o diretório (restart PTY)
- **Clean slate na UI**: delete de toda a complexidade visual
- **Backend mantido**: HookIPCServer + SessionManager + NotificationService + SessionStore
  continuam funcionando silenciosamente (base para expansão futura)

## Arquivos a criar

| Arquivo | O que faz |
|---|---|
| `ClaudeTerminal/Features/Terminal/MainView.swift` | Nova view principal: header com path + botão "Open in…" + terminal embedded rodando `claude` |

## Arquivos a modificar

| Arquivo | O que muda |
|---|---|
| `ClaudeTerminal/App/ClaudeTerminalApp.swift` | Troca `DashboardView` por `MainView`; remove SwiftData (`.modelContainer`); remove WindowGroups extras (quick-terminal, quick-agent, agent-terminal) |
| `ClaudeTerminal/App/AppDelegate.swift` | Remove `observeSessionStore()` e referência a `SessionStore.shared.pendingHITLCount`; badge inicia sempre em 0 e só muda quando HookIPCServer receber HITL |
| `ClaudeTerminal/Services/SessionManager.swift` | Remove a linha `SessionStore.shared.remove(sessionID: sid)` no handler de `.stopped` (SessionStore ainda existe mas não é responsabilidade do actor limpar) |

## Arquivos a deletar (UI)

```text
ClaudeTerminal/Features/Dashboard/DashboardView.swift
ClaudeTerminal/Features/Dashboard/AgentCardView.swift
ClaudeTerminal/Features/Dashboard/NewAgentSheet.swift
ClaudeTerminal/Features/TaskBacklog/TaskBacklogView.swift
ClaudeTerminal/Features/TaskBacklog/BetDrawSheet.swift
ClaudeTerminal/Features/SkillRegistry/SkillRegistryView.swift
ClaudeTerminal/Features/SkillRegistry/SkillEntry.swift
ClaudeTerminal/Features/SkillRegistry/SkillRegistryService.swift
ClaudeTerminal/Features/Onboarding/OnboardingView.swift
ClaudeTerminal/Features/Terminal/QuickTerminalView.swift
ClaudeTerminal/Features/Terminal/QuickAgentView.swift
ClaudeTerminal/Features/Terminal/AgentTerminalView.swift
ClaudeTerminal/Features/Terminal/SpawnedAgentView.swift
```

## Arquivos a deletar (Models / Services desnecessários)

```text
ClaudeTerminal/Models/ClaudeTask.swift
ClaudeTerminal/Models/ClaudeAgent.swift
ClaudeTerminal/Models/ClaudeProject.swift
ClaudeTerminal/Models/Bet.swift
ClaudeTerminal/Models/AppMigrationPlan.swift
ClaudeTerminal/Models/SchemaV1.swift
ClaudeTerminal/Models/SchemaV2.swift
ClaudeTerminal/Models/SchemaV3.swift
ClaudeTerminal/Models/AgentTerminalConfig.swift
ClaudeTerminal/Models/QuickTerminalConfig.swift
ClaudeTerminal/Models/QuickAgentConfig.swift
ClaudeTerminal/Models/AgentEvent.swift
ClaudeTerminal/Services/SettingsWriter.swift
ClaudeTerminal/Services/WorktreeManager.swift
```

## Passos de execução

1. Criar `MainView.swift` — header + terminal embedded
2. Modificar `ClaudeTerminalApp.swift` — trocar view principal, remover SwiftData e WindowGroups extras
3. Modificar `AppDelegate.swift` — remover observação de SessionStore
4. Modificar `SessionManager.swift` — remover linha SessionStore.shared.remove()
5. Deletar os 14 arquivos de UI
6. Deletar os 14 arquivos de Models/Services
7. Verificar build

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal (Package.swift): verificar se referências a SwiftData precisam de ajuste
- [ ] Novas dependências: não

## Rollback

```bash
git reset --hard HEAD  # descarta tudo no worktree
# ou
git revert <commit>    # após PR merged
```

## Learnings aplicados

- PTY deve usar `zsh -l -i -c "cd '...' && claude"` para herdar PATH completo do usuário
- `.id(sessionID)` no terminal para forçar recreação quando o diretório mudar
- `NSOpenPanel` chamado sem `Task`/`await` — views são `@MainActor`
- Manter backend (HookIPCServer, SessionManager) mesmo limpando a UI — evita perder infra valiosa

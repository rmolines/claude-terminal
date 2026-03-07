# Plan: session-controls

## Problema

Três friction points no uso diário:
1. Não há como inserir quebra de linha sem submeter o prompt (Shift+Enter não faz nada especial)
2. Não há botão para reiniciar o processo claude em um terminal sem fechar/reabrir o projeto
3. Ao atualizar o app via Sparkle, o contexto do terminal (scrollback) é perdido porque snapshots não são salvos antes do relaunch

## Assunções

- [assumed][background] `LocalProcessTerminalView` é `open class` e pode ser subclassada para interceptar `keyDown`
- [assumed][background] Sparkle chama `updaterWillRelaunchApplication` antes de reiniciar — pode ser usado como hook
- [assumed][background] Claude Code interpreta `0x0a` (`\n`) via PTY como quebra de linha sem submit (readline `quoted-insert` ou similar)

## Deliverables

### Deliverable 1 — Shift+Enter multiline

**O que faz:** Subclasse `ClaudeTerminalView: LocalProcessTerminalView` que intercepta Shift+Enter e envia `\n` (0x0a) ao PTY em vez do Enter padrão.

**Critério de done:** No terminal com Claude Code rodando, Shift+Enter insere uma nova linha no input sem submeter.

**Arquivos:**
- Novo: `ClaudeTerminal/Features/Terminal/ClaudeTerminalView.swift`
- Edit: `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift` — trocar `LocalProcessTerminalView` por `ClaudeTerminalView`

### Deliverable 2 — Botão Restart

**O que faz:** Botão "Restart" no header de `ProjectDetailView`. Ao clicar, incrementa `terminalRevision[currentPath]` (UUID), forçando SwiftUI a destruir e recriar o `LocalProcessTerminalView`. O PTY fecha (SIGHUP para claude), novo processo inicia.

**Critério de done:** Clicar no botão fecha o processo claude atual e inicia um novo no mesmo diretório, sem precisar fechar/reabrir o projeto.

**Arquivos:**
- Edit: `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — `@State terminalRevision`, botão no header, `.id()` nos terminals do ZStack

### Deliverable 3 — Sparkle snapshot preservation

**O que faz:** `AppDelegate` passa `self` como `updaterDelegate` ao `SPUStandardUpdaterController` e implementa `updaterWillRelaunchApplication(_:)` para salvar todos os snapshots antes do relaunch do Sparkle.

**Critério de done:** Após update via Sparkle, o scrollback dos terminais é restaurado no próximo launch (mesmo comportamento do quit manual).

**Arquivos:**
- Edit: `ClaudeTerminal/App/AppDelegate.swift` — conformar `SPUUpdaterDelegate`, passar `self` como delegate, implementar hook

## Arquivos a modificar

- `ClaudeTerminal/Features/Terminal/ClaudeTerminalView.swift` — novo arquivo
- `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift` — usar `ClaudeTerminalView`
- `ClaudeTerminal/Features/Terminal/ProjectDetailView.swift` — restart button + revision tracking
- `ClaudeTerminal/App/AppDelegate.swift` — Sparkle delegate

## Passos de execução

1. Criar `ClaudeTerminalView.swift` com subclasse que intercepta Shift+Enter [Deliverable 1]
2. Editar `TerminalViewRepresentable.swift` para usar `ClaudeTerminalView` em vez de `LocalProcessTerminalView` [Deliverable 1]
3. Editar `ProjectDetailView.swift`: `@State terminalRevision`, botão restart no header, `.id()` nos terminals [Deliverable 2]
4. Editar `AppDelegate.swift`: `SPUUpdaterDelegate` conformance + `updaterWillRelaunchApplication` [Deliverable 3]

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

```bash
git checkout main -- ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift
git checkout main -- ClaudeTerminal/Features/Terminal/ProjectDetailView.swift
git checkout main -- ClaudeTerminal/App/AppDelegate.swift
rm ClaudeTerminal/Features/Terminal/ClaudeTerminalView.swift
```

## Learnings aplicados

- `NSPanel hidesOnDeactivate`: não se aplica
- `LocalProcessTerminalView` requires one `DispatchQueue` per instance — mantido, subclasse não muda isso
- `SPUStandardUpdaterController` com `updaterDelegate: nil` — a correção é exatamente passar `self`

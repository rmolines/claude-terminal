# CLAUDE.md — Claude Terminal

## Visão geral

**Claude Terminal** é um app macOS nativo que funciona como Mission Control para uma squad
de agentes Claude Code rodando em paralelo. Em vez de gerenciar N janelas de terminal
empilhadas, o dev cria tasks, acompanha progresso em tempo real e aprova pedidos HITL sem
quebrar o foco.

**WHY:** Dev solo usando Claude Code como força multiplicadora não tem interface projetada para
esse workflow — tem um amontoado de terminais de texto e zero contexto sobre o que cada agente
está fazendo.

**WHAT:** Dashboard com status de cada agente (tokens, fase da skill, sub-agentes em
background), menu bar com badge de HITL pendentes, backlog de tasks persistente (SwiftData),
e terminal opcional para inspecionar a sessão raw do Claude Code.

**HOW:** Claude Code hooks → `ClaudeTerminalHelper` (thin CLI, lê stdin JSON) → Unix domain
socket → `HookIPCServer` (actor) → `SessionManager` (actor) → `@MainActor` → SwiftUI.

## Stack

- **Swift 6.2** com `defaultIsolation = MainActor` em todos os targets
- **SwiftUI 70% + AppKit 30%** — NSStatusItem manual, NSPanel para HUD flutuante
- **SwiftTerm** (`LocalProcessTerminalView`) — PTY engine, uma `DispatchQueue` por instância
- **SwiftData** para entidades de negócio (ClaudeTask, ClaudeAgent); Core Data para event streams de alta frequência
- **SecureXPC** — IPC tipado entre app e helper com verificação por audit token (não PID)
- **Unix Domain Socket** — hooks → app, latência ~2-5µs, `~/Library/Application Support/ClaudeTerminal/hooks.sock`
- Distribuição: DMG notarizado via `xcrun notarytool`, fora da App Store
- CI: `swift build` em `macos-15`; Release: `swift build -c release` → bundle manual → sign Developer ID → notarize → DMG

## Critical rules — NEVER do without explicit approval

- Nunca commit de tokens, keys ou passwords — usar env vars ou secret managers
- Nunca force-push para main — sempre PRs com CI verde
- Nunca `--no-verify` em hooks — corrigir o problema subjacente
- Nunca modificar `~/.claude/settings.json` sem escrita atômica (`replaceItem`) — TOCTOU
- Nunca passar args de hook diretamente para shell — sempre allowlist (CVE-2025-59536)
- Nunca usar PID para validar identidade XPC — audit token obrigatório

## Feature workflow

1. `/start-feature <nome>` — intake + hot files → worktree → plano
2. Implementar no worktree em `.claude/worktrees/<nome>`
3. `/ship-feature` — build + tests + PR
4. `/close-feature` — cleanup + LEARNINGS.md

## Hot files — ler SEMPRE antes de planejar qualquer feature

| Arquivo | Por quê |
|---|---|
| `Shared/IPCProtocol.swift` | Contrato entre app e helper — mudanças afetam ambos os targets |
| `ClaudeTerminal/Services/HookIPCServer.swift` | Critical path de todos os eventos dos agentes |
| `ClaudeTerminal/Services/SessionManager.swift` | Actor central — estado mutável de sessões ativas |
| `ClaudeTerminal/Models/ClaudeTask.swift` | Schema SwiftData — mudanças requerem `VersionedSchema` |
| `ClaudeTerminal/Models/ClaudeAgent.swift` | Schema SwiftData — idem |
| `ClaudeTerminalHelper/main.swift` | Entry point do helper — afetado por mudanças de protocolo |
| `.github/workflows/release.yml` | Pipeline de notarização — ler antes de mudar targets/entitlements |
| `app.entitlements` + `helper.entitlements` | Entitlements — mudanças podem causar falha na notarização |
| `Package.swift` | Dependências e targets — mudanças afetam CI |

## Armadilhas conhecidas

| Componente | Armadilha | Solução |
|---|---|---|
| SwiftData | Array ordering não preservado ao recarregar | Adicionar `sortOrder: Int` em todos os arrays |
| SwiftData | Auto-save não é confiável | Sempre `context.save()` após mutations |
| SwiftData | `ModelContext` não é thread-safe | Um contexto por actor/thread |
| SwiftData | `let` em propriedades de relacionamento crasha em runtime | Sempre `var` e optional |
| SwiftData | `Task` como nome de @Model causa conflito | Usar `ClaudeTask` |
| XPC | Validar identidade por PID é vulnerável a race condition | `xpc_connection_set_peer_code_signing_requirement` (audit token) |
| SwiftTerm | `DispatchQueue.main` compartilhada trava UI com 4+ agentes | Uma queue separada por instância de `LocalProcessTerminalView` |
| Hooks | Input não sanitizado → RCE via repo malicioso | Allowlist antes de qualquer execução (CVE-2025-59536) |
| Code signing | Ordem errada causa falha no Gatekeeper | Helper PRIMEIRO, frameworks, app por último — nunca `--deep` |
| SwiftUI @main + SPM | Conflito com `main.swift` no mesmo target | Usar `@main` OU `main.swift`, nunca ambos |
| bootstrap.yml | Só dispara no primeiro push (`run_number == 1`) | Não re-rodar manualmente |
| gh pr merge | `--delete-branch` falha em worktree (`main` já checked out no repo pai) | Usar `--squash` sem `--delete-branch`; deletar remote via `gh api -X DELETE repos/.../git/refs/heads/<branch>` |
| SPM executável | `@testable import` não funciona em `.executableTarget` | Mover lógica testável para `.target` (library); ou usar actor mirror local no test file |
| SPM binário (sem .app bundle) | Keyboard input não funciona — janelas não recebem events do OS | `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps: true)` em `applicationDidFinishLaunching` |
| SPM binário (sem .app bundle) | `Bundle.main.bundleIdentifier` é nil → erros de window tabs, SwiftData, notificações | Embedar `Info.plist` via linker flag: `.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "ClaudeTerminal/App/Info.plist"])` em `Package.swift` |
| NavigationSplitView sidebar | `@FocusState` + `TextField` mostra anel mas não recebe keyboard | Usar `NSViewRepresentable` com `NSTextField` que chama `window.makeFirstResponder(field)` diretamente |
| PTY environment | PATH hardcoded não inclui `~/.local/bin`, nvm, etc. | Usar `zsh -l -i -c "..."` para herdar PATH completo do usuário |
| Worktree + plan.md | Escrever `plan.md` no working tree do `main` antes de criar worktree → arquivo fica não-rastreado, bloqueia `git pull` após merge | Sempre escrever `plan.md` no path do worktree: `/worktrees/<feature>/...` |
| Implementação no main em vez do worktree | Agente implementa arquivos diretamente no `main` (sem worktree) → arquivos ficam como unstaged em `main`, precisam ser copiados manualmente para o worktree antes do commit | Sempre confirmar o CWD antes de criar arquivos: `git branch --show-current` deve retornar `feature/<nome>` |
| Curly quotes em string interpolation Swift | `"texto \(var)"` com aspas tipográficas (`"..."`) dentro do literal quebra o parser do Swift com erro críptico de `FormatStyle` | Usar aspas retas escapadas: `\"` dentro de string interpolation |

## Worktree convention

- Path: `.claude/worktrees/<feature-name>`
- Branch: `feature/<feature-name>` (kebab-case)
- Sempre fazer `git fetch origin && git rebase origin/main` antes de começar

## Secrets

| Secret (GitHub Actions) | Uso |
|---|---|
| `CERTIFICATE_P12_BASE64` | Certificado Developer ID em base64 |
| `CERTIFICATE_PASSWORD` | Senha do .p12 |
| `KEYCHAIN_PASSWORD` | Senha do keychain temporário no CI |
| `APPLE_ID` | Apple ID para notarização |
| `NOTARIZATION_PASSWORD` | App-specific password do appleid.apple.com |
| `TEAM_ID` | Team ID do Developer account |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for signing Sparkle updates |

Nenhum secret é necessário para desenvolvimento local — apenas para o pipeline de release.

## Daily commands

```bash
make help            # Lista todos os comandos disponíveis
make check           # Lint + validate
swift build          # Build local de todos os targets
swift test           # Rodar testes
```

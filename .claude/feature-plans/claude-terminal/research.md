# Research — Claude Terminal
_Gerado em: 2026-02-27_

---

## Stack validada

### Swift 6.2
- **Versão recomendada:** Swift 6.2 (Xcode 16.3+)
- **Feature crítica:** `defaultIsolation = MainActor` — toda declaração assume `@MainActor` por padrão; elimina a maioria dos erros de cross-actor em código UI
- **`nonisolated(nonsending)` padrão:** funções async nonisolated rodam no actor do chamador, não em thread pool separado — menos erros de cross-actor
- **Migração incremental:** `SWIFT_STRICT_CONCURRENCY=targeted` em Swift 5.10 → corrigir warnings → `complete` → mudar para Swift 6 language mode
- **Gotcha:** ao ativar `defaultIsolation = MainActor`, pacotes SPM de terceiros que assumem ausência de `@MainActor` podem falhar compilação
- **Para N sessões PTY paralelas:** cada sessão em `AsyncStream` + `Task` com herança de actor; evitar `Task.detached`
- Links: [Swift 6.2 Released](https://www.swift.org/blog/swift-6.2-released/) | [Migration Guide](https://github.com/swiftlang/swift-migration-guide)

### SwiftUI + AppKit
- **Padrão 2025:** SwiftUI 70% (views, estado, binding) + AppKit 30% (NSStatusItem, NSPanel, integrações de sistema)
- **Menu bar:** `NSStatusItem` manual via AppDelegate — mais controle que `MenuBarExtra` SwiftUI; sem delay de popover (~100ms)
- **HUD flutuante:** `NSPanel` com `isFloatingPanel = true`, `level = .floating`, `hidesOnDeactivate = true` — aparece sobre fullscreen, recebe teclado sem roubar foco da janela principal
- **Interop:** `NSViewRepresentable` para embedar AppKit (SwiftTerm) em SwiftUI; `NSHostingView` para embedar SwiftUI em AppKit
- **Gotcha:** `NSHostingView` não resize automaticamente em todos os contextos — use `setFrameSize` + `intrinsicContentSize` corretamente
- Links: [Floating Panel in SwiftUI](https://cindori.com/developer/floating-panel) | [WWDC22 — Use SwiftUI with AppKit](https://developer.apple.com/videos/play/wwdc2022/10075/)

### SwiftTerm (terminal engine)
- **Versão:** ativa, último commit fev/2026 (Kitty input no main branch)
- **Apps em produção:** Secure Shellfish, La Terminal, CodeEdit
- **Integração SwiftUI:**
  ```swift
  struct TerminalViewRepresentable: NSViewRepresentable {
      func makeNSView(context: Context) -> LocalProcessTerminalView {
          let tv = LocalProcessTerminalView(frame: .zero)
          try? tv.startProcess(executable: "/bin/zsh", args: [])
          return tv
      }
  }
  ```
- **Múltiplas instâncias:** passar `DispatchQueue` personalizada por instância — sem `DispatchQueue.main` compartilhada
- **Thread safety:** frame-based rendering com batching resolve #137; parsing em background, rendering 1x por frame
- **Sandbox:** `LocalProcessTerminalView` **não funciona** em app com sandbox completo — requer entitlements de processo ou sandbox desabilitada (nosso caso: DMG notarizado fora da App Store)
- **Alternativa (libghostty):** GPU-accelerated via Metal, mas C API interna instável, fork privado — não recomendado para dependência externa
- Links: [SwiftTerm GitHub](https://github.com/migueldeicaza/SwiftTerm) | [SwiftTermApp (referência multi-sessão)](https://github.com/migueldeicaza/SwiftTermApp)

### SwiftData (macOS 14+)
- **Uso correto:** entidades de negócio (Task, Agent, configurações) — **NÃO** para event streams de alta frequência
- **Para streams de eventos:** Core Data diretamente ou GRDB — SwiftData tem performance insatisfatória para inserts massivos
- **Bugs conhecidos:**
  - Array ordering não preservado → adicionar campo `sortOrder: Int` manual
  - Relacionamentos devem ser `var` optional (não `let`, não non-optional)
  - `context.save()` explícito obrigatório — auto-save não é confiável
  - Predicados em to-many relationships com optionals: performance ruim
  - Acima de ~500 items, `@Query` pode causar 100% CPU idle (bug Xcode 15.3+)
- **Schema migration:** usar `VersionedSchema` desde o primeiro release (custo zero, evita dívida futura)
- **Thread safety:** criar um `ModelContext` por thread/actor — nunca compartilhar entre threads
- Links: [SwiftData Pitfalls (Wade Tregaskis)](https://wadetregaskis.com/swiftdata-pitfalls/) | [VersionedSchema Guide](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema)

### IPC: Unix Domain Socket + SecureXPC
- **Hooks → app:** Unix Domain Socket em `~/Library/Application Support/ClaudeTerminal/hooks.sock`
  - Latência ~2-5µs por roundtrip
  - Sem restrições de sandbox para app fora da App Store
  - Permissões 0600 no socket; validar `getpeereid()` antes de aceitar conexão
  - Implementar heartbeat a cada 5s para detectar processo morto
- **App → helper (IPC bidirecional tipado):** [SecureXPC](https://github.com/trilemma-dev/SecureXPC)
  - Type-safety com Codable, async/await nativo
  - Verificação de identidade do caller por certificado (não PID — vulnerável a race condition)
  - Routes tipadas: `XPCRoute.named("agent.event").withMessageType(AgentEvent.self)`
- **Helper lifecycle:** `SMAppService` (macOS 13+) — substitui `SMJobBless`, helper em `Contents/Library/HelperTools/`
- Links: [SecureXPC GitHub](https://github.com/trilemma-dev/SecureXPC) | [HelperToolApp (referência SMAppService)](https://github.com/alienator88/HelperToolApp)

### Notificações HITL (UNUserNotificationCenter)
- Funciona normalmente fora da sandbox
- Ações background (sem abrir o app): `UNNotificationAction` **sem** `.foreground` option
- Categorias de ação com approve/reject são registradas no launch
- App recebe `didReceive response:` mesmo em background — responde ao hook via socket
- **Gotcha macOS:** ações aparecem ao expandir notificação (hover) ou right-click — não são visíveis imediatamente
- `requestAuthorization` deve incluir `.alert`, `.sound`, `.badge` — `.alert` é obrigatório para ações aparecerem
- Links: [UNNotificationAction Docs](https://developer.apple.com/documentation/usernotifications/unnotificationaction)

### Code Signing e Notarização
- **Ferramenta:** `xcrun notarytool` (não `altool` — removido em 2023)
- **Ordem de assinatura (crítico):** bottom-up — helper binary PRIMEIRO, frameworks, app por último
- **NUNCA usar `codesign --deep`** — não funciona bem para bundles complexos
- **Hardened Runtime** (`--options runtime`) obrigatório para notarização
- **Stapling obrigatório:** `xcrun stapler staple YourApp.dmg` — incorpora ticket para validação offline
- **Entitlements para PTY fora da sandbox:** nenhum especial necessário — PTY usa syscalls POSIX normais
- **CI:** GitHub Actions em `runs-on: macos-14`; secrets necessários: `CERTIFICATE_P12_BASE64`, `CERTIFICATE_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_ID`, `NOTARIZATION_PASSWORD`, `TEAM_ID`
- Links: [Notarization Workflow (Apple)](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) | [GitHub Actions para notarização](https://federicoterzi.com/blog/automatic-code-signing-and-notarization-for-macos-apps-using-github-actions/)

---

## Padrões arquiteturais recomendados

### Concurrency
- `@MainActor` por padrão (via `defaultIsolation`) para todo código de UI
- `AsyncStream` para bridging entre callbacks PTY (C-land) e Swift concurrency
- Uma `DispatchQueue` por sessão SwiftTerm (não compartilhar `DispatchQueue.main`)
- Actor dedicado `SessionManager` para estado mutável de sessões ativas

### IPC pipeline (hooks → app)
```
Claude Code hook (qualquer evento)
    → stdin JSON com session_id, cwd, hook_event_name
    → claude-terminal-helper (thin CLI, lê stdin)
    → Unix Domain Socket / XPC → app principal (Swift actor)
    → MainActor → atualiza UI
```

### Worktrees (uma worktree por agente)
```
git worktree add -b claude/<task-title>_<nanoseconds> \
    ~/.config/claude-terminal/worktrees/<branch> HEAD
```
- Branch nomeado com timestamp em nanosegundos garante unicidade
- `baseCommitSHA` salvo ao criar — usado para diffs e futura criação de PR
- `git worktree prune` no startup do app — limpa resíduos de sessões anteriores

---

## Checklist de segurança (fase de arquitetura)

### P0 — Antes de qualquer linha de código de produção

| Item | Decisão de arquitetura |
|---|---|
| **XPC identity validation** | `xpc_connection_set_peer_code_signing_requirement` (macOS 12+) — NÃO validar por PID (vulnerável a PID reuse attack) |
| **Hardened Runtime entitlements mínimos** | NUNCA: `cs.disable-library-validation`, `cs.allow-unsigned-executable-memory`, `cs.disable-executable-page-protection` |
| **Sanitização de args dos hooks** | NÃO passar args do hook diretamente para shell. UUID e paths validados como allowlist |
| **Verificar assinatura do helper antes de executar** | `SecStaticCodeCheckValidity` com requirement de Team ID + Bundle ID específico |
| **Escrita atômica em settings.json** | Write para arquivo temp + `FileManager.replaceItem` — evita TOCTOU race condition |

**CVE ativo relevante:** [CVE-2025-59536](https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/) — repositórios maliciosos modificam `.claude/settings.json` local para RCE via hooks. O helper binary é o ponto de execução — validação de input é crítica.

### P1 — Antes de distribuir

| Item | Detalhe |
|---|---|
| Code signing completo | Bottom-up: helper → frameworks → app; verifica com `codesign --verify --deep --strict` |
| Permissões 0700 em Application Support | `~/Library/Application Support/ClaudeTerminal/` — apenas o usuário lê |
| Filtrar env vars antes de fork | Allowlist de `PATH`, `HOME`, `TERM` — evitar vazamento de `ANTHROPIC_API_KEY` para processo filho |
| Socket restrito ao uid atual | `chmod 0600` no socket; validar `getpeereid()` |
| Disclosure no README | O que é armazenado localmente, como remover, zero telemetria |

### P2 — Nice-to-have

- Rate limiting de sessões no helper (max 10 simultâneas)
- `os_log` para auditoria de eventos de segurança (sem conteúdo de prompts)
- Verificação periódica de integridade do helper em runtime (não só no launch)
- `SMAppService` para registro seguro do helper no launchd

---

## Compliance relevante

- **LGPD/GDPR:** risco legal baixo — app pessoal, open source, sem backend, sem coleta centralizada. Disclosure no README satisfaz princípio de transparência. Não é necessário DPA, cookie banner ou DPO.
- **App Store:** incompatível por design (PTY requer ausência de sandbox). Distribuição via DMG notarizado é o caminho correto.
- **Notarização Apple:** entitlements sensíveis (`temporary-exception.*`) podem ser negados pela Apple na revisão. Evitar.

---

## Aprendizados dos projetos de referência

| Projeto | Decisão a copiar | Decisão a evitar |
|---|---|---|
| **cmux** | Unix socket `/tmp/<app>.sock` com helper thin CLI; parsing off-main; OSC 9/777 para notificações contextuais no terminal | libghostty (C API interna instável, fork privado); AGPL (copyleft) |
| **claude-squad** | `git worktree add -b <title>_<nanoseconds>` para unicidade; `baseCommitSHA` tracking; `git worktree prune` no startup | Polling por hash de tela (CPU-intensivo, frágil); dependência de tmux |
| **SwiftTerm** | `LocalProcessTerminalView` com `DispatchQueue` por instância; frame-based rendering sem display links próprios | `DispatchQueue.main` compartilhada; sandbox completo |
| **SecureXPC** | Routes tipadas com Codable; verificação por certificado (não PID); async/await nativo | `SMJobBless` (deprecated macOS 13+) |
| **Claude Code Hooks** | Eventos via stdin JSON: `Notification`+`permission_prompt` (HITL), `Stop` (tarefa concluída), `PreToolUse` (bloqueio) | — |
| **SwiftBar** | Badge numerico via `NSImage` draw overlay no NSStatusItem | URL schemes para notificações (usar UNNotificationCenter) |

---

## Dependências e versões fixadas

```swift
// Package.swift — dependências externas mínimas
dependencies: [
    // Terminal engine
    .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.3.0"),

    // IPC tipado entre app e helper
    .package(url: "https://github.com/trilemma-dev/SecureXPC", from: "0.8.0"),
],
```

**Sem frameworks de UI de terceiros** — SwiftUI + AppKit nativos são suficientes.

**SwiftData** é nativo (macOS 14+) — sem dependência adicional. Para event streams considerar GRDB se performance for insatisfatória.

---

## Estrutura de diretórios recomendada

```
ClaudeTerminal/
├── ClaudeTerminal.xcodeproj/
├── ClaudeTerminal/                    # App principal (target)
│   ├── App/
│   │   ├── ClaudeTerminalApp.swift    # @main, AppDelegate, NSStatusItem setup
│   │   └── AppDelegate.swift          # Menu bar, janelas, lifecycle
│   ├── Features/
│   │   ├── Dashboard/                 # Lista de agentes ativos
│   │   ├── TaskBacklog/               # Backlog de tasks (SwiftData)
│   │   ├── HITL/                      # Painel de aprovação inline
│   │   └── Terminal/                  # SwiftTerm NSViewRepresentable wrapper
│   ├── Models/                        # SwiftData @Model classes
│   │   ├── Task.swift
│   │   ├── Agent.swift
│   │   └── AgentEvent.swift
│   ├── Services/
│   │   ├── HookIPCServer.swift        # Unix domain socket server
│   │   ├── SessionManager.swift       # Actor — gerencia PTY sessions
│   │   ├── WorktreeManager.swift      # git worktree create/cleanup
│   │   ├── SettingsWriter.swift        # Escrita atômica em ~/.claude/settings.json
│   │   └── NotificationService.swift  # UNUserNotificationCenter
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
├── ClaudeTerminalHelper/              # Helper binary (target separado)
│   ├── main.swift                     # Entry point: conecta socket, recebe hooks
│   ├── HookHandler.swift              # Parse e valida stdin JSON dos hooks
│   └── IPCClient.swift                # Envia para app via XPC/socket
├── Shared/                            # Código compartilhado entre targets
│   ├── IPCProtocol.swift              # Tipos Codable para IPC
│   └── AgentEventType.swift           # Enum de eventos dos hooks
└── .github/
    └── workflows/
        ├── ci.yml
        └── release.yml                # Build + notarize + attach DMG ao release
```

**Decisões de estrutura:**
- `Features/` por domínio (não por tipo de arquivo) — escala melhor com múltiplos colaboradores
- `Services/` para I/O e efeitos colaterais — testável sem UI
- Helper binary como target Xcode separado no mesmo `.xcodeproj` — simplifica signing e bundling
- `Shared/` target para tipos comuns — evita duplicação entre app e helper

---

## Claude Code Hooks — referência técnica

**Configuração instalada automaticamente pelo app em `~/.claude/settings.json`:**

```json
{
  "hooks": {
    "Notification": [{
      "hooks": [{
        "type": "command",
        "command": "/Applications/ClaudeTerminal.app/Contents/MacOS/claude-terminal-helper notify",
        "async": true
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "/Applications/ClaudeTerminal.app/Contents/MacOS/claude-terminal-helper stop",
        "async": true
      }]
    }],
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "/Applications/ClaudeTerminal.app/Contents/MacOS/claude-terminal-helper guard"
      }]
    }]
  }
}
```

**JSON recebido pelo helper (stdin):**
```json
{
  "session_id": "abc123",
  "transcript_path": "/Users/.../.claude/projects/.../transcript.jsonl",
  "cwd": "/Users/user/project",
  "hook_event_name": "Notification",
  "tool_name": "Bash",
  "tool_input": { "command": "..." }
}
```

**Eventos mapeados para o Mission Control:**

| Evento Hook | Trigger | Ação no app |
|---|---|---|
| `Notification` + `permission_prompt` | Agente precisa de aprovação | Badge menu bar +1; notificação nativa com Approve/Reject |
| `Stop` | Agente finalizou | Status → `completed`; atualizar UI |
| `PreToolUse` (Bash) | Agente vai rodar comando | Verificar allowlist; retornar exit code 0 (allow) ou 2 (block) |
| `Notification` (geral) | Qualquer notificação do agente | Atualizar status em tempo real |

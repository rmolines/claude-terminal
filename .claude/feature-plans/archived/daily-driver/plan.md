# Plan: daily-driver

## Problema

O app não é usável como substituto do iTerm hoje porque:
1. Criar uma sessão exige criar uma task, depois linkar um terminal — muita fricção
2. Ao abrir o terminal, a shell está "suja" (zsh puro, sem `claude` rodando)
3. Os cards são pequenos e não mostram o que o Claude está dizendo
4. Não tem como responder ao Claude sem abrir a janela do terminal completa

## Arquivos a modificar

| Arquivo | O que muda |
|---|---|
| `ClaudeTerminalHelper/HookHandler.swift` | Extrair `toolInput["message"]` para `.notification` events |
| `Shared/IPCProtocol.swift` | (nenhuma — rota de notificação já existe via `detail`) |
| `ClaudeTerminal/Services/SessionManager.swift` | Adicionar `recentMessages: [String]` a `AgentSession`; popular via `.notification` events |
| `ClaudeTerminal/App/ClaudeTerminalApp.swift` | Adicionar `WindowGroup "quick-agent"` |
| `ClaudeTerminal/Features/Dashboard/DashboardView.swift` | Adicionar botão + método `openQuickAgent()` |
| `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift` | Adicionar `replyRoutingCwd: String?`, subscriber NotificationCenter |
| `ClaudeTerminal/Features/Terminal/SpawnedAgentView.swift` | Passar `replyRoutingCwd: config.worktreePath` ao `TerminalViewRepresentable` |
| `ClaudeTerminal/Features/Dashboard/AgentCardView.swift` | Adicionar seção de mensagens recentes + reply box |

## Arquivos novos

| Arquivo | O que é |
|---|---|
| `ClaudeTerminal/Models/QuickAgentConfig.swift` | Clone de `QuickTerminalConfig` com campo `sessionID: String` |
| `ClaudeTerminal/Features/Terminal/QuickAgentView.swift` | Clone de `QuickTerminalView` que roda `claude` e passa `replyRoutingCwd` |

## Passos de execução

### Passo 1 — `HookHandler.swift`: extrair mensagem de notificação

Em `mapEventType`, o `detail` para `.notification` é sempre `nil`. Claude Code inclui
o texto da notificação em `toolInput["message"]`. Mudar para:

```swift
if eventType == .bashToolUse {
    detail = payload.toolInput?["command"].map { String($0.prefix(80)) }
} else if eventType == .permissionRequest {
    detail = payload.toolInput?["description"].map { String($0.prefix(80)) }
} else if eventType == .notification {
    detail = payload.toolInput?["message"].map { String($0.prefix(200)) }
} else {
    detail = nil
}
```

### Passo 2 — `SessionManager.swift`: adicionar `recentMessages` a `AgentSession`

Adicionar a `AgentSession`:
```swift
var recentMessages: [String] = []   // últimas 3 notificações do Claude
```

Em `handleEvent()`, no case `.notification`, após `updateOrCreate`:
```swift
case .notification:
    updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)
    if let msg = event.detail, !msg.isEmpty {
        var msgs = sessions[event.sessionID]?.recentMessages ?? []
        msgs.insert(msg, at: 0)
        if msgs.count > 3 { msgs = Array(msgs.prefix(3)) }
        sessions[event.sessionID]?.recentMessages = msgs
    }
```

### Passo 3 — `QuickAgentConfig.swift` (novo arquivo)

Clone de `QuickTerminalConfig`, com `sessionID: String` extra (UUID pré-gerado usado
como routing key para o reply box):

```swift
struct QuickAgentConfig: Codable, Hashable {
    var id: UUID
    var sessionID: String      // routing key para NotificationCenter
    var directoryPath: String
    var displayTitle: String

    init(directoryPath: String) {
        self.id = UUID()
        self.sessionID = UUID().uuidString
        self.directoryPath = directoryPath
        self.displayTitle = URL(fileURLWithPath: directoryPath).lastPathComponent
    }
}
```

### Passo 4 — `TerminalViewRepresentable.swift`: subscriber NotificationCenter

Adicionar parâmetro `replyRoutingCwd: String? = nil`.

Na `Coordinator`, adicionar:
```swift
var inputObserver: NSObjectProtocol?

deinit {
    if let obs = inputObserver {
        NotificationCenter.default.removeObserver(obs)
    }
}
```

Em `makeNSView`, após iniciar o processo, adicionar:
```swift
if let cwd = replyRoutingCwd {
    let obs = NotificationCenter.default.addObserver(
        forName: NSNotification.Name("ClaudeTerminal.SessionReply"),
        object: nil,
        queue: .main
    ) { [weak tv] notification in
        guard let userInfo = notification.userInfo,
              let notifCwd = userInfo["cwd"] as? String,
              notifCwd == cwd,
              let text = userInfo["text"] as? String else { return }
        let bytes = Array((text + "\n").utf8)
        tv?.send(data: bytes[...])
    }
    context.coordinator.inputObserver = obs
}
```

### Passo 5 — `QuickAgentView.swift` (novo arquivo)

Clone de `QuickTerminalView` com duas diferenças:
1. Usa `QuickAgentConfig` em vez de `QuickTerminalConfig`
2. Roda `claude` em vez de `exec zsh`
3. Passa `replyRoutingCwd: config.directoryPath` ao `TerminalViewRepresentable`

```swift
// Diferença no terminal:
TerminalViewRepresentable(
    executable: "/bin/zsh",
    args: ["-l", "-i", "-c", "cd '\(escaped)' && claude"],
    environment: [...],
    replyRoutingCwd: config.directoryPath
)
```

Ícone no header: `brain.head.profile` (para distinguir do terminal puro).

### Passo 6 — `SpawnedAgentView.swift`: passar `replyRoutingCwd`

Na var `terminal`, adicionar `replyRoutingCwd: config.worktreePath` ao
`TerminalViewRepresentable`. Nenhuma outra mudança.

### Passo 7 — `ClaudeTerminalApp.swift`: registrar WindowGroup `quick-agent`

Após o WindowGroup do `quick-terminal`, adicionar:
```swift
WindowGroup("Claude Agent", id: "quick-agent", for: QuickAgentConfig.self) { $config in
    if let c = config {
        QuickAgentView(config: c)
    }
}
```

### Passo 8 — `DashboardView.swift`: botão "New Session"

Adicionar método `openQuickAgent()` (espelho de `openQuickTerminal()` mas com
`QuickAgentConfig`):
```swift
private func openQuickAgent() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.title = "Select Project Directory"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    openWindow(id: "quick-agent", value: QuickAgentConfig(directoryPath: url.path))
}
```

Adicionar toolbar button antes do "New Agent":
```swift
ToolbarItem(placement: .primaryAction) {
    Button { openQuickAgent() } label: {
        Label("New Session", systemImage: "sparkles")
    }
    .help("Open a new Claude Code session in any directory")
}
```

### Passo 9 — `AgentCardView.swift`: output preview + reply box

**Reestruturar `body` para incluir 3 seções:**

```swift
var body: some View {
    TimelineView(.periodic(from: .now, by: 1.0)) { _ in
        VStack(alignment: .leading, spacing: 0) {
            topRow
                .padding(.horizontal, 12).padding(.top, 10)
                .onTapGesture { showTerminal = true }
            bottomRow
                .padding(.horizontal, 12).padding(.top, 4)
            if !session.recentMessages.isEmpty {
                Divider().padding(.top, 6)
                messagesPreview
                    .padding(.horizontal, 12).padding(.top, 6)
            }
            if session.status == .running || session.status == .awaitingInput {
                Divider().padding(.top, 6)
                replyBox
                    .padding(.horizontal, 12).padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(...)
    }
    .popover(isPresented: $showTerminal) {
        AgentTerminalView(session: session).frame(width: 720, height: 440)
    }
}
```

**Adicionar `@State private var replyText = ""`**

**`messagesPreview`:**
```swift
private var messagesPreview: some View {
    VStack(alignment: .leading, spacing: 3) {
        ForEach(session.recentMessages.prefix(3), id: \.self) { msg in
            Text(msg)
                .font(.system(.caption2, design: .default))
                .foregroundStyle(.primary.opacity(0.75))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding(.bottom, 2)
}
```

**`replyBox`:**
```swift
@State private var replyText = ""

private var replyBox: some View {
    HStack(spacing: 6) {
        TextField("Reply to Claude…", text: $replyText)
            .font(.caption)
            .textFieldStyle(.plain)
            .onSubmit { sendReply() }
        Button(action: sendReply) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(replyText.isEmpty ? .secondary : .blue)
        }
        .buttonStyle(.plain)
        .disabled(replyText.isEmpty)
    }
}

private func sendReply() {
    guard !replyText.isEmpty else { return }
    let text = replyText
    replyText = ""
    NotificationCenter.default.post(
        name: NSNotification.Name("ClaudeTerminal.SessionReply"),
        object: nil,
        userInfo: ["cwd": session.cwd, "text": text]
    )
}
```

**Também adicionar ao `.bottomRow`, mover o `.onTapGesture` do activityText para estar
só no texto, não no Spacer (evitar conflito de tap com o replyBox).**

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não
- [ ] SwiftData migration: não (mudanças só em structs in-memory `AgentSession`)

## Rollback

```bash
git revert HEAD  # se já commitado
# ou
git checkout -- .  # se ainda não commitado
```

Os dois novos arquivos (`QuickAgentConfig.swift`, `QuickAgentView.swift`) podem ser
deletados sem impacto; as mudanças nos arquivos existentes são aditivas (novos campos
opcionais + novos parâmetros com default = nil).

## Learnings aplicados

- **PTY environment PATH**: usar `-l -i` em `QuickAgentView` (já no `SpawnedAgentView`)
- **`@FocusState` + TextField em List**: usar `NSViewRepresentable` se foco não funcionar
  (CLAUDE.md) — reply box usa `TextField` nativo SwiftUI; se foco falhar, trocar por
  `NSViewRepresentable`
- **Actor + blocking I/O**: `updateOrCreate` no `SessionManager` é síncrono dentro do
  actor; manipulação de `recentMessages` é in-memory (sem I/O)
- **NotificationCenter thread safety**: `addObserver(forName:object:queue:.main)` é
  thread-safe; não viola isolamento de ator
- **Swift 6 `nonisolated`**: `Coordinator.deinit` é `nonisolated` por default — ok para
  `removeObserver`

# Research: daily-driver

## Descrição da feature

Tornar o app utilizável como substituto real do iTerm no dia a dia — quatro melhorias
concretas para transformar o dashboard de "monitor passivo" em "centro de controle ativo":

1. **Quick session creation** — clicar '+' e imediatamente ter um card de Claude Code sem
   precisar criar task primeiro
2. **Auto-start `claude`** — terminal abre já rodando `claude` (não uma shell suja)
3. **Cards maiores com output preview** — ver as últimas linhas do que o Claude está escrevendo
4. **Reply box no card** — responder ao Claude diretamente do dashboard, estilo WhatsApp

## Arquivos existentes relevantes

### Core data flow
- `Shared/IPCProtocol.swift` — `HookPayload` (tem `transcriptPath: String?`, não lido hoje),
  `AgentEvent`, `TokenUsage`
- `Shared/AgentEventType.swift` — tipos de evento: notification, bashToolUse, permissionRequest,
  stopped, subAgentStarted, heartbeat
- `ClaudeTerminal/Services/SessionManager.swift` — actor central; `AgentSession` struct com
  `currentActivity`, tokens, status; `handleEvent()` é o ponto de extensão para output preview
- `ClaudeTerminal/Services/SessionStore.swift` — bridge `@Observable @MainActor` → SwiftUI

### Views
- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — grid com `LazyVGrid(.adaptive(min:280))`;
  botão `[New Agent]` abre `NewAgentSheet`, botão `[Terminal]` abre `QuickTerminalView`
- `ClaudeTerminal/Features/Dashboard/AgentCardView.swift` — card fixo ~100pt de altura;
  status dot + cwd + timer no topo; activity + badges embaixo
- `ClaudeTerminal/Features/Dashboard/NewAgentSheet.swift` — fluxo atual: pick task →
  enter repo → create worktree → `spawnAgent()` → `openWindow(id: "agent-terminal", value: config)`
- `ClaudeTerminal/Features/Terminal/SpawnedAgentView.swift` — janela com `zsh -l -i -c "cd '<worktree>' && claude"`;
  já auto-inicia `claude` com `-l -i` para PATH completo
- `ClaudeTerminal/Features/Terminal/QuickTerminalView.swift` — janela com `zsh -l -i -c "cd '<dir>' && exec zsh"`;
  **não** inicia `claude` — é o template correto para o novo Quick Agent
- `ClaudeTerminal/Features/Terminal/AgentTerminalView.swift` — popover do card; abre `zsh` puro
  no cwd (sem `-l -i`, sem `claude`) — é um shell de inspeção, não a sessão real
- `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift` — `NSViewRepresentable`
  wrappando `LocalProcessTerminalView`; tem `initialInput` + `1.5s delay` já implementado;
  uma `DispatchQueue` UUID-labeled por instância

### Models
- `ClaudeTerminal/Models/AgentTerminalConfig.swift` — `Codable & Hashable` para
  `WindowGroup "agent-terminal"`: `sessionID`, `worktreePath`, `taskTitle`, `skillCommand`
- `ClaudeTerminal/Models/QuickTerminalConfig.swift` — `Codable & Hashable` para
  `WindowGroup "quick-terminal"`: `id`, `directoryPath`, `displayTitle`
- `ClaudeTerminal/Models/ClaudeAgent.swift` — `@Model` SwiftData; não precisa existir para
  sessões sem task
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — 3 `WindowGroup`s hoje: dashboard,
  `"agent-terminal"`, `"quick-terminal"`

## Padrões identificados

- **Quick session sem task** é um padrão já existente: `QuickTerminalView` faz exatamente isso,
  só precisa rodar `claude` em vez de `exec zsh`
- **Auto-start** já está resolvido: `SpawnedAgentView` usa `zsh -l -i -c "cd '<dir>' && claude"`.
  O novo flow deve copiar esse padrão
- **Output preview**: `transcriptPath` chega em todo `HookPayload` mas nunca é lido; lê as
  últimas 2KB do arquivo, divide por newlines, filtra linhas em branco, retorna as últimas 5
- **Reply box → PTY**: `NotificationCenter` é a ponte correta — card posta
  `NSNotification.Name("SessionInput.<sessionID>")`, `TerminalViewRepresentable` subscreve e
  chama `tv.send(data:)` na mesma queue do terminal; evita violar Swift 6 actor isolation
- **Taller cards**: `LazyVGrid(.adaptive(minimum: 280))` controla largura, não altura;
  altura é determinada pelo conteúdo — basta adicionar seções ao card

## Dependências externas

Nenhuma — tudo usa APIs existentes (SwiftUI, SwiftTerm, NotificationCenter, FileManager)

## Hot files que serão tocados

- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — novo botão '+' para quick agent
- `ClaudeTerminal/Features/Dashboard/AgentCardView.swift` ⚠️ — output preview + reply box
- `ClaudeTerminal/Services/SessionManager.swift` ⚠️ — `AgentSession.outputPreview: [String]`,
  `AgentSession.pendingInput: String?`, leitura de transcriptPath
- `ClaudeTerminal/Features/Terminal/TerminalViewRepresentable.swift` ⚠️ — observer NotificationCenter
- `ClaudeTerminal/App/ClaudeTerminalApp.swift` — novo `WindowGroup "quick-agent"`

## Arquivos novos

- `ClaudeTerminal/Models/QuickAgentConfig.swift` — `Codable & Hashable` para quick agent
  (clone de `QuickTerminalConfig` com `launchClaude: true`)
- `ClaudeTerminal/Features/Terminal/QuickAgentView.swift` — clone de `QuickTerminalView` que
  roda `claude` em vez de `exec zsh`

## Riscos e restrições

| Risco | Severidade | Mitigação |
|---|---|---|
| Swift 6: `NotificationCenter` post de `@MainActor`, observer em `DispatchQueue` do PTY | Baixa | NotificationCenter é thread-safe; usar `queue: .main` no observer é safe |
| `transcriptPath` pode não existir em sessões sem task | Baixa | `guard let path = event.transcriptPath` + `FileManager.fileExists` |
| Leitura de transcriptPath a cada evento (I/O frequente) | Média | Throttle: só atualizar se `lastEventAt` > 3s desde última leitura |
| `LocalProcessTerminalView` `send(data:)` chamado antes do PTY estar pronto | Baixa | Já resolvido pelo `1.5s delay` existente em `TerminalViewRepresentable` |
| Curly quotes em string interpolation Swift | Baixa | Usar aspas retas `\"` dentro de string interpolation (CLAUDE.md) |
| PATH sem `claude` no novo quick agent | Baixa | Copiar exatamente `zsh -l -i -c "cd '<dir>' && claude"` de SpawnedAgentView |

## Fontes consultadas

- Análise do codebase (subagente A)
- Web research: Warp, Ghostty, Zellij patterns 2025-2026 (subagente B)
- Tech estimate: complexidade e riscos por improvement (subagente C)

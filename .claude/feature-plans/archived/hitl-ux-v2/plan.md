# Plan: hitl-ux-v2

## Problema

O painel de HITL exibe apenas "Approve" e "Reject" hardcoded. Claude Code já envia
`permission_suggestions` no payload do `PermissionRequest` hook — IDs como `yes-session`
que mapeiam para opções mais granulares (allow-once vs allow-for-session). Esses IDs são
ignorados. Usuários não conseguem conceder permissão de sessão a partir do app, só via
terminal interativo.

Problema estrutural subjacente: o protocolo de resposta socket (1 byte: 0=deny, 1=allow)
é insuficiente para qualquer resposta mais rica — show-in-terminal, Elicitation, updatedInput.
Cada feature nova forçaria um patch ad hoc. Este plano resolve os dois juntos.

## Assunções

<!-- status: [assumed] = não verificada | [verified] = confirmada | [invalidated] = refutada -->
<!-- risco:   [blocking] = falsa bloqueia a implementação | [background] = emerge naturalmente -->

- [assumed][blocking] `permission_suggestions` é campo top-level no JSON do PermissionRequest (não dentro de `toolInput`)
- [assumed][blocking] PTY key order: `0x31`=allow-once, `0x32`=allow-session, `0x1b`=reject (ESC)
- [assumed][background] `{"permissionDecision":"ask"}` escrito no stdout do helper faz Claude Code mostrar TUI e aguardar keypress
- [assumed][background] `permission_suggestions` pode ser nil/vazio — fallback para Approve/Reject
- [verified] Socket response atual: 1 byte (0=deny, 1=allow); helper traduz para exit code (0 ou 2)

## Questões abertas

**Resolver antes de começar:**
- Nenhuma — assunções verificáveis em runtime com fallback seguro

**A implementação vai responder:**
- Se `permission_suggestions` aparece no payload real (confirmado via engenharia reversa do binário, mas pode variar por hook type)
- Se PTY key `0x32` aciona "allow for session" na versão atual do Claude Code

**Explicitamente fora do escopo:**
- Hook `Elicitation` — D1 cria a fundação de protocolo, mas a UI de formulário é feature separada
- `updatedInput` no PreToolUse — idem
- Parsing de choice menus PTY-only (sem hook) — documentado como não construível

## Deliverables

### Deliverable 1 — HookResponse protocol (fundação)

**O que faz:** Substitui o protocolo de resposta socket de 1-byte por `HookResponse: Codable`
com JSON length-prefixed. App envia `HookResponse { decision, ptyKey }` para o helper; helper
interpreta e escreve stdout + exit code corretos para o Claude Code.

`ptyKey` no response elimina a necessidade de `approveHITL(ptyKey:)` adhoc — o caller inclui
o byte no response; o helper repassa ao PTY.

Estrutura do `HookResponse`:

```swift
public struct HookResponse: Codable, Sendable {
    public let decision: String   // "allow" | "deny" | "ask"
    public let ptyKey: UInt8?     // byte para enviar ao PTY (nil = não enviar)
    // Campos futuros: elicitationContent, updatedInput (nil = ignorado pelo helper)
}
```

Helper constrói o stdout JSON para Claude Code a partir do `HookResponse`:
- `"allow"` → exit 0, sem stdout
- `"deny"` → exit 2, sem stdout
- `"ask"` → exit 0, stdout `{"permissionDecision":"ask"}`

**Critério de done:** PermissionRequest funciona identicamente ao comportamento atual
(approve/reject) com o novo protocolo. Build verde. Nenhuma regressão.

**Valida:** que o protocolo JSON é extensível sem breaking changes.

**Deixa aberto:** botões dinâmicos e "show in terminal" (Deliverable 2).

**Execute `/checkpoint` antes de continuar para o Deliverable 2.**

### Deliverable 2 — Dynamic buttons + Show in terminal

**O que faz:** Constrói sobre a fundação do D1.

1. Propaga `permission_suggestions` do payload Claude Code até o card HITL
2. Card renderiza botões distintos: "Allow this time" (`ptyKey: 0x31`), "Allow for session"
   (`ptyKey: 0x32`), "Reject" (`0x1b` + decision: deny) — fallback para Approve/Reject se
   suggestions vier nil
3. Botão "Show in terminal" envia `HookResponse { decision: "ask", ptyKey: nil }` — Claude
   Code mantém TUI aberto para o usuário decidir no terminal

**Critério de done:** Card de HITL mostra botões distintos por tipo de permissão; "Show in
terminal" despacha o dialog para o PTY e remove o item da fila no painel.

**Valida:** assunções de PTY key order e `permission_suggestions` no payload.

## Arquivos a modificar

### Deliverable 1

- `Shared/IPCProtocol.swift` — novo `HookResponse: Codable, Sendable`; remover `HITLDecision` enum (não precisa mais — `decision` é String no response)
- `ClaudeTerminal/Services/HookIPCServer.swift` — `respondHITL(decision: String, ptyKey: UInt8?)` que serializa e envia `HookResponse` como length-prefixed JSON
- `ClaudeTerminal/Services/SessionManager.swift` — atualizar `approveHITL` e `rejectHITL` para passar `HookResponse` fields; PTY input vem do `ptyKey` no response
- `ClaudeTerminalHelper/IPCClient.swift` — `sendAndAwaitResponse` lê length-prefixed JSON em vez de 1 byte; retorna `HookResponse`
- `ClaudeTerminalHelper/HookHandler.swift` — switch no `response.decision` para stdout JSON e exit code

### Deliverable 2

- `Shared/IPCProtocol.swift` — `HookPayload.permissionSuggestions: [String]?` (CodingKey: `permission_suggestions`); `AgentEvent.permissionSuggestions: [String]?`
- `ClaudeTerminalHelper/HookHandler.swift` — extrair suggestions e incluir no `AgentEvent`
- `ClaudeTerminal/Services/SessionManager.swift` — `AgentSession.pendingSuggestions: [String]`; armazenar no case `.permissionRequest`; novos métodos `approveHITL(sessionID:ptyKey:)` e `showInTerminalHITL(sessionID:)`
- `ClaudeTerminal/Features/SessionCards/ApprovalCardView.swift` — `PermissionSuggestion` struct; `HITLItem.suggestions: [PermissionSuggestion]`; `HITLItem.onShowInTerminal: (() -> Void)?`; action row dinâmica
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — construir sugestões a partir de `session.pendingSuggestions`; callbacks por sugestão

## Passos de execução

### Deliverable 1

1. `Shared/IPCProtocol.swift` — adicionar `HookResponse: Codable, Sendable` com `decision: String` e `ptyKey: UInt8?` [D1]
2. `ClaudeTerminalHelper/IPCClient.swift` — `sendAndAwaitResponse` passa a ler 4 bytes (length) + JSON body; decodifica `HookResponse`; retorna struct [D1]
3. `ClaudeTerminalHelper/HookHandler.swift` — switch no `response.decision`: `"allow"` → exit 0; `"deny"` → exit 2; `"ask"` → print stdout JSON + exit 0; PTY input agora é responsabilidade do app (via `ptyKey`) [D1]
4. `ClaudeTerminal/Services/HookIPCServer.swift` — `respondHITL(decision: String, ptyKey: UInt8?)` serializa `HookResponse` com length-prefix e escreve no fd [D1]
5. `ClaudeTerminal/Services/SessionManager.swift` — atualizar `approveHITL` e `rejectHITL` para usar novo `respondHITL`; `approveHITL` passa `ptyKey: 0x31`; `rejectHITL` passa `decision: "deny", ptyKey: 0x1b` [D1]

**Execute `/checkpoint` — Deliverable 1 concluído**

### Deliverable 2

6. `Shared/IPCProtocol.swift` — adicionar `permissionSuggestions: [String]?` a `HookPayload` e `AgentEvent` [D2]
7. `ClaudeTerminalHelper/HookHandler.swift` — extrair `payload.permissionSuggestions` e incluir no `AgentEvent` [D2]
8. `ClaudeTerminal/Services/SessionManager.swift` — adicionar `pendingSuggestions: [String]` em `AgentSession`; armazenar no `.permissionRequest`; adicionar `showInTerminalHITL` que envia `decision: "ask"` [D2]
9. `ClaudeTerminal/Features/SessionCards/ApprovalCardView.swift` — `PermissionSuggestion` struct; atualizar `HITLItem`; action row dinâmica com fallback [D2]
10. `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — construir suggestions; callbacks por sugestão + `onShowInTerminal` [D2]

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda (hooks já registrados)
- [ ] Novas dependências: não

## Rollback

D1 é uma mudança de protocolo interna (app + helper compilados juntos). Revert completo via
`git revert`. Campos novos em D2 (`permissionSuggestions`) são `optional` — backward-compatible
se helper antigo não os enviar.

## Learnings aplicados

- Campos novos em structs `Codable` de IPC: sempre `optional` com default `nil`
- PTY input: enviar apenas `[byte]` sem `\r` — raw mode processa 1 byte; `0x0d` vaza para o próximo diálogo
- `NSHostingView.rootView` crash (macOS 26): já resolvido com `HITLPanelState @Observable` — não tocar em `rootView =`
- Actor → @MainActor bridge: toda mutação com reflexo na UI termina com `Task { @MainActor in SessionStore.shared.update(session) }`
- `[String: Any]` não é `Codable` — usar campos tipados ou `String` para JSON raw; helper constrói o stdout JSON final

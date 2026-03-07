# Plan: hitl-reject-with-reason

## Problema

Quando o usuário rejeita um PermissionRequest, o agente não recebe contexto sobre o motivo.
O agente para ou retenta sem saber o que fazer diferente — o dev precisa abrir o terminal
e digitar manualmente. Um campo opcional de instrução após rejeitar, injetado no PTY, elimina
essa fricção sem mudar o fluxo principal.

## Assunções

- [verified][blocking] `TerminalRegistry.sendInput([UInt8], forCwd:)` aceita qualquer sequência de bytes — incluindo texto UTF-8 + `\n`
- [assumed][background] 1.5s de delay entre o `0x1b` (ESC dismiss da TUI) e a injeção do texto é suficiente para o Claude Code voltar ao prompt

## Questões abertas

**A implementação vai responder:**
- Se o delay de 1.5s é adequado na prática (pode ajustar se o texto aparecer antes do prompt)

**Explicitamente fora do escopo:**
- Suggestions dinâmicas (yes-session etc.) — o botão "Reject" das suggestions continua sem o two-step nesta feature
- Persistência do histórico de rejeições

## Deliverables

### Deliverable 1 — Reject com instrução opcional

**O que faz:** Two-step no botão Reject do fallback: primeiro clique expande um TextField
inline; segundo clique (Send) envia a rejeição + injeta a instrução no PTY com delay de 1.5s.

**Critério de done:** Clicar Reject expande o campo. Digitar instrução e confirmar → o texto
aparece no terminal do agente após a rejeição.

## Arquivos a modificar

- `ClaudeTerminal/Services/SessionManager.swift` — novo `rejectHITL(sessionID:reason:)` que injeta `reason` no PTY após 1.5s se não vazio; refatora `rejectHITL(sessionID:)` para chamar o novo método com `reason: ""`
- `ClaudeTerminal/Features/SessionCards/ApprovalCardView.swift` — `HITLItem.onReject: () -> Void` → `onReject: (String) -> Void`; `ApprovalCardView` ganha `@State var rejectExpanded` + `@State var rejectReason`; actionRow fallback: Reject expande TextField + Send/Cancel
- `ClaudeTerminal/Features/HITL/HITLFloatingPanelController.swift` — atualiza `onReject` para `{ reason in Task { await SessionManager.shared.rejectHITL(sessionID: ..., reason: reason) } }`

## Passos de execução

1. `SessionManager.swift` — adicionar `rejectHITL(sessionID: String, reason: String) async` com PTY injection de `reason`; manter `rejectHITL(sessionID:)` como atalho com `reason: ""`
2. `ApprovalCardView.swift` — mudar assinatura `onReject`; adicionar states; two-step no actionRow fallback; atualizar previews para `onReject: { _ in }`
3. `HITLFloatingPanelController.swift` — atualizar callsite `onReject`

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

`git revert HEAD` — mudanças são aditivas e auto-contidas.

## Learnings aplicados

- PTY input: enviar apenas `[byte]` sem `\r` para single-byte inputs; para texto livre, UTF-8 + `[0x0a]` (`\n`) funciona no prompt Claude Code
- PTY input timing: usar `DispatchQueue.main.asyncAfter(deadline: .now() + 1.5)` entre dismiss (0x1b) e injeção do texto
- `HITLItem` usa `onReject: () -> Void` — mudar para `(String) -> Void` requer atualizar apenas o controller e os previews

# Research: HITL UX v2 — Arquitetura PTY do Claude Code

Investigação realizada em 2026-03-06 por engenharia reversa do binário `claude` (v2.1.70, Bun-compiled JS).

## Objetivo

Entender abrangentemente como o Claude Code expõe interações de usuário para determinar o que é construível na UI sem modificar o Claude Code.

---

## Arquitetura de comunicação

Claude Code usa dois canais independentes e simultâneos para interagir com o usuário:

```
Claude Code (processo)
│
├── Hook system (JSON via stdin de subprocesso)
│   └── ClaudeTerminalHelper → socket → HookIPCServer → SessionManager
│
└── PTY (raw terminal — bytes ANSI/keystrokes)
    └── LocalProcessTerminalView (SwiftTerm) → TerminalRegistry
```

Quando um `PermissionRequest` dispara, **ambos os canais ativam simultaneamente**:
- Hook system: bloqueia, aguarda exit code do helper (0=allow, 2=deny)
- PTY: exibe diálogo TUI em raw mode, aguarda keypress

---

## Taxonomia completa de hooks (extraída do binário)

### Hooks que já tratamos

| Hook | Trigger | Nosso tratamento |
|---|---|---|
| `PermissionRequest` | Qualquer ferramenta precisa de permissão | exit 0 + `0x31` ao PTY |
| `Notification` | Mensagens gerais do agente | forwarding async |
| `PreToolUse` (Bash) | Antes de rodar comando bash | observação apenas |
| `Stop` | Agente completou | atualiza status |
| `UserPromptSubmit` | Usuário submeteu prompt | detecta `/` commands |

### Hooks descobertos — não tratados

| Hook | Trigger | Input | Response |
|---|---|---|---|
| `Elicitation` | MCP server solicita input estruturado | `{mcp_server_name, message, requested_schema}` | `{hookSpecificOutput: {action, content}}` |
| `ElicitationResult` | Após resposta do usuário a elicitation | `{mcp_server_name, action, content, mode, elicitation_id}` | pode sobrescrever resposta |
| `SessionEnd` | Sessão encerrando | `{reason}` | observação |
| `ConfigChange` | Arquivos de config mudam durante sessão | `{source, file_path}` | exit 2 bloqueia a mudança |
| `InstructionsLoaded` | CLAUDE.md carregado | `{file_path, memory_type, load_reason}` | observação |
| `PostToolUse` | Após execução de ferramenta | `{inputs, response}` | pode modificar output |

### Tipos de Notification descobertos (não tratados)

A Notification hook tem `notification_type` com os seguintes valores:
- `permission_prompt` — diálogo de permissão sendo exibido
- `idle_prompt` — agente ocioso
- `auth_success` — autenticação bem-sucedida
- `elicitation_dialog` — diálogo de elicitation apareceu
- `elicitation_complete` — elicitation completada
- `elicitation_response` — resposta de elicitation recebida

---

## Descoberta crítica 1: `permission_suggestions` no payload do PermissionRequest

O hook já envia as opções que seriam exibidas no PTY TUI.

Do código interno (linha 138408 do bundle):
```js
hook_event_name: "PermissionRequest",
tool_name: T,
tool_input: R,
permission_suggestions: $   // ← opções do diálogo PTY
```

O campo `permission_suggestions` contém os IDs das sugestões. IDs encontrados no binário:

| ID | Label no PTY |
|---|---|
| `yes-session` | "Yes, allow all edits during this session" / "Yes, allow reading from X during this session" |
| `reject` | "No, don't allow" |
| *(allow-once implícito)* | "Yes, allow this time" |
| *(project-scope)* | "Yes, allow reading from X from this project" |
| *(always)* | "Yes, and always allow access to X" |
| *(pattern)* | "Yes, and don't ask again for X commands in Y" |

**Implicação**: Se passarmos `permission_suggestions` do `HookPayload` até o `HITLItem`, podemos renderizar botões dinâmicos em vez de Approve/Reject hardcoded. Cada sugestão vira um botão com label correto.

**Mudanças necessárias**:
1. `HookPayload` — adicionar `permissionSuggestions: [String]?`
2. `AgentEvent` — adicionar `permissionSuggestions: [String]?`
3. `HITLItem` — adicionar `suggestions: [PermissionSuggestion]`
4. `ApprovalCardView` — renderizar um botão por sugestão

---

## Descoberta crítica 2: Hook `Elicitation` — múltiplas opções via MCP

Este é o mecanismo formal para MCP servers solicitarem input estruturado do usuário. **Não existe no nosso código.**

### Fluxo

```
MCP server chama elicitation API
    → Claude Code dispara hook Elicitation (bloqueante)
    → Nossa resposta: { hookSpecificOutput: { action, content } }
    → Exit 0: usa resposta; Exit 2: nega
```

### Payload de input

```json
{
  "hook_event_name": "Elicitation",
  "mcp_server_name": "github",
  "message": "Select the branch to target:",
  "requested_schema": {
    "type": "object",
    "properties": {
      "branch": {
        "type": "string",
        "enum": ["main", "develop", "feature/x"]
      }
    },
    "required": ["branch"]
  }
}
```

### Resposta esperada (via hookSpecificOutput)

```json
{
  "hookSpecificOutput": {
    "action": "accept",
    "content": { "branch": "main" }
  }
}
```

Ações possíveis: `"accept"` | `"decline"` | `"cancel"`

### Por que isso importa

É exatamente o caso "quando Claude dá mais de uma opção" para qualquer MCP server.
O `requested_schema` é JSON Schema — pode definir:
- `enum` → radio buttons ou dropdown
- `string` → campo de texto
- `boolean` → toggle
- `object` com múltiplas propriedades → formulário completo

**Mudanças necessárias**:
1. Registrar `Elicitation` em `~/.claude/settings.json`
2. Novo `AgentEventType.elicitation`
3. Novo tipo de `HITLItem` com `requestedSchema: [String: Any]`
4. Novo card que renderiza form a partir do JSON Schema
5. `ClaudeTerminalHelper` responde com JSON em vez de exit code simples

---

## Descoberta crítica 3: Schema completo da resposta de hooks

O Claude Code aceita um schema rico como resposta (não apenas exit code):

```json
{
  "continue": false,
  "suppressOutput": false,
  "stopReason": "string",
  "decision": "approve | block",
  "reason": "string",
  "systemMessage": "string",
  "permissionDecision": "allow | deny | ask",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow | deny | ask",
    "permissionDecisionReason": "string",
    "updatedInput": {}
  }
}
```

**`permissionDecision: "ask"`**: Diz ao Claude Code para mostrar o PTY dialog mesmo assim. Equivalente a "deixar o terminal decidir" — útil como terceiro botão na UI.

**`updatedInput`** (PreToolUse): Permite modificar o input da ferramenta antes de executar. Ex: usuário edita um comando bash antes de aprovar.

**Nota**: `decision` (top-level) está deprecated para PreToolUse — usar `hookSpecificOutput.permissionDecision`.

---

## O que ainda é PTY-only (não construível)

Quando o Claude Code escreve escolhas diretamente no terminal sem usar hooks:

```
What would you like to do?
1. Continue with current approach
2. Start fresh
3. Cancel
```

Não existe hook para isso. Claude Code simplesmente escreve texto e aguarda keypress.
Detectar via parsing do buffer SwiftTerm seria possível (`rangeChanged` + `getBufferAsData`),
mas é extremamente frágil — quebraria a cada update do Claude Code.

**Conclusão**: Esses casos PTY-only existem mas são minoria. O design correto é:
- App trata o que tem hook (PermissionRequest + Elicitation)
- Terminal trata o que não tem (choice menus PTY-only)

---

## Mapa de implementação

### Prioridade 1 — Permission suggestions (alto impacto, escopo pequeno)

- `HookPayload.permissionSuggestions: [String]?`
- `AgentEvent.permissionSuggestions: [String]?`
- `HITLItem.suggestions: [PermissionSuggestion]` onde `PermissionSuggestion = (id: String, label: String, ptyKey: UInt8, hookDecision: String)`
- Mapeamento: `yes-session` → label localizado + `0x32` ao PTY + `allow` no hook; `reject` → `0x1b` + `deny`
- `ApprovalCardView` renderiza botões dinamicamente

### Prioridade 2 — Elicitation hook (alto impacto, escopo médio)

- Registrar hook em settings
- Novo `AgentEventType.elicitation`
- `ElicitationItem: HITLItem` com `requestedSchema`
- `ElicitationCardView` com renderizador de JSON Schema
- Helper responde JSON (não apenas exit code)

### Prioridade 3 — `permissionDecision: "ask"` (low effort)

- Botão "Mostrar no terminal" → helper retorna `{"permissionDecision": "ask"}` + nenhum byte ao PTY
- Útil quando usuário quer ver contexto completo antes de decidir

### Prioridade 4 — `updatedInput` (médio impacto, médio escopo)

- Botão "Editar e aprovar" abre editor inline no card
- Helper retorna `{"hookSpecificOutput": {"updatedInput": <editado>}}`

---

## Armadilhas antecipadas

| Componente | Armadilha |
|---|---|
| `permission_suggestions` | Campo pode ser nil/vazio em versões antigas do Claude Code — fallback para Approve/Reject |
| Elicitation + PTY | Claude Code ainda mostra o diálogo PTY em paralelo com o hook — precisamos enviar `0x1b` (ou equivalente de dismiss) ao aprovar via app |
| `updatedInput` | Só funciona em PreToolUse, não em PermissionRequest — verificar `hookEventName` antes de usar |
| Helper JSON response | Atualmente helper só usa exit code. Mudar para stdout JSON requer atualizar o parser do Claude Code e o protocolo socket |

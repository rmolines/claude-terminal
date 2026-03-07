# Plan: hitl-rich-context-card

## Problema

O card de HITL mostra contexto insuficiente para o dev decidir Approve/Reject sem abrir o terminal:
- Ferramentas de arquivo (Write, Edit, Read) mostram apenas o nome da tool como `detail` — `toolInput["file_path"]` nunca é extraído
- O `toolName` é exibido como texto monoespaçado simples sem cor ou ícone — não há distinção visual por categoria de tool
- Resultado: dev precisa abrir o PTY para saber "Write em qual arquivo?" ou "Bash rodando qual comando?"

## Assunções

- [verified][blocking] `toolInput["command"]` já é extraído corretamente para Bash em `HookHandler.swift`
- [assumed][blocking] `toolInput` para Write/Edit/Read contém a key `"file_path"`; para Glob/Grep contém `"path"` ou `"pattern"`
- [assumed][background] `AgentEvent.detail` já chega corretamente ao `session.currentActivity` em SessionManager — sem mudança necessária no pipeline IPC

## Questões abertas

**A implementação vai responder:**
- Quais keys exatas `toolInput` envia para cada tool (verificar com log em runtime se necessário)

**Explicitamente fora do escopo:**
- `permission_suggestions` / botões dinâmicos (cobertos por `hitl-ux-v2`)
- Reject + instrução (coberto por `hitl-reject-with-reason`)
- WorkSessionRowView inline HITL — mesmos dados, não precisa de mudança de exibição

## Deliverables

### Deliverable 1 — Extração de file_path no HookHandler

**O que faz:** Expande a lógica de extração de `detail` para permissionRequest: tenta `command` → `file_path` → `path` → `pattern` → `description` → `toolName`. Aumenta prefix de 80 para 120 chars.

**Critério de done:** Card de HITL mostra o path de arquivo para Write/Edit/Read e o comando para Bash — sem "Awaiting approval" genérico para ferramentas conhecidas.

**Valida:** assunção de que `toolInput["file_path"]` existe para ferramentas de arquivo.

### Deliverable 2 — Tool badge com ícone + cor

**O que faz:** Substitui `Text(tool)` em `ApprovalCardView` por um `ToolBadge` view com SF Symbol + label + capsule colorida por categoria:
- `Bash` → `terminal` icon, `.red` tint
- `Write` → `square.and.arrow.down` icon, `.blue` tint
- `Edit` / `MultiEdit` → `square.and.pencil` icon, `.blue` tint
- `Read` / `Glob` / `Grep` → `magnifyingglass` icon, `.secondary`
- `WebFetch` / `WebSearch` → `globe` icon, `.teal` tint
- outros → `wrench.and.screwdriver` icon, `.secondary`

**Critério de done:** Card renderiza badge colorido com ícone; `RenderPreview` confirma visual antes do merge.

## Arquivos a modificar

- `ClaudeTerminalHelper/HookHandler.swift` — expand detail extraction chain para permissionRequest
- `ClaudeTerminal/Features/SessionCards/ApprovalCardView.swift` — adicionar `ToolBadge` view, substituir `Text(tool)` no `headerRow`

## Passos de execução

1. `HookHandler.swift` — expandir chain de extração do `detail` em `permissionRequest` [D1]
2. `ApprovalCardView.swift` — adicionar `ToolBadge` struct + substituir `Text(tool)` no `headerRow` + verificar com `RenderPreview` [D2]

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

`git revert` dos commits — ambas as mudanças são isoladas e não afetam o protocolo IPC.

## Learnings aplicados

- `toolInput["command"]` para Bash, não `"description"` — já estava correto; extender para `"file_path"`/`"path"` para ferramentas de arquivo
- PTY badge: NSHostingView crash (macOS 26) — não tocamos em HITLFloatingPanelController nem rootView, mudança é só no ApprovalCardView leaf view

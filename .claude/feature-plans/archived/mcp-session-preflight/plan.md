# Plan: mcp-session-preflight

## Problema

Skills MCP-dependentes (`/design-review`, `/ship-feature`) falham silenciosamente quando o
Xcode MCP não está conectado — o usuário descobre o problema mid-session depois de `/clear`.
`/clear` destrói conexões MCP irreversivelmente (sem reconnect automático no Claude Code).

## Assunções

- [assumed][verified] MCP Xcode é hard dependency em exatamente 2 pontos: `RenderPreview` em
  `/design-review` e `BuildProject` em `/ship-feature` (derivado do explore.md)
- [assumed][verified] Não há API para verificar status de MCP server mid-session — só é possível
  tentar usar a ferramenta e observar se falha
- [assumed][background] Fases 0, A, B de `start-feature` são completamente MCP-free

## Deliverables

### Deliverable 1 — Handoff session-type + UI prerequisite warning

**O que faz:**
- 3 blocos de handoff em `start-feature.md` recebem anotação de tipo de sessão:
  Fase 0 e Fase A => Type A (somente texto); Fase B => Type A ou B dependendo de presença
  de arquivos SwiftUI no plan.md gerado
- Fase C.1 (leitura do plan.md) recebe lógica: se plan.md menciona arquivos `.swift` em
  views, exibir aviso "abra Package.swift no Xcode antes de iniciar"

**Critério de done:** Handoff blocks e Fase C.1 atualizados e legíveis. Nenhuma funcionalidade
de skills existente quebrada.

### Deliverable 2 — Preflight probe em skills MCP-dependentes

**O que faz:**
- `design-review.md`: Adicionar bloco "Preflight MCP" no topo da seção "Configuracao do
  projeto" — tenta `RenderPreview` em arquivo dummy ou verifica `ListMcpResourcesTool`;
  se falhar => exibe mensagem específica nomeando a ação de remediação (`open Package.swift`)
  em vez de falhar com erro genérico
- `ship-feature.md`: Passo 0.5 ganha lógica: tentar `BuildProject` (MCP) primeiro para
  saída estruturada; se MCP não disponível => fallback silencioso para `{{BUILD_CMD}}`
  (`swift build`) com `Xcode MCP não conectado — usando swift build (sem saída estruturada)`

**Critério de done:** Ambas as skills têm bloco de preflight explícito antes de usar MCP.

## Arquivos a modificar

- `.claude/commands/start-feature.md` — 4 edições: 3 handoff blocks + Fase C.1
- `.claude/commands/design-review.md` — 1 edição: preflight MCP no topo
- `.claude/commands/ship-feature.md` — 1 edição: passo 0.5 com MCP probe + fallback

## Passos de execução

1. `start-feature.md` — atualizar bloco handoff Fase 0 (Type A) [D1]
2. `start-feature.md` — atualizar bloco handoff Fase A (Type A) [D1]
3. `start-feature.md` — atualizar bloco handoff Fase B (Type A/B + lógica) [D1]
4. `start-feature.md` — atualizar Fase C.1: aviso de pré-requisito UI [D1]
5. `design-review.md` — adicionar bloco "Preflight MCP" [D2]
6. `ship-feature.md` — atualizar passo 0.5 com MCP probe + fallback [D2]

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

```bash
git checkout main -- .claude/commands/start-feature.md
git checkout main -- .claude/commands/design-review.md
git checkout main -- .claude/commands/ship-feature.md
```

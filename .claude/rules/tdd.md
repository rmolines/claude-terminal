# Rule: TDD para escrita de código

## O princípio central

**Se você não viu o teste falhar, você não sabe se o teste está testando a coisa certa.**

Testes escritos depois do código passam imediatamente — e isso prova nada:
podem testar o que foi construído (não o que era necessário) e perder edge cases.

## Ciclo obrigatório

1. **RED** — escrever o teste. Rodá-lo. Ver falhar.
2. **GREEN** — escrever o mínimo de código para passar.
3. **REFACTOR** — limpar. Manter verde.

Se o teste passou sem implementar nada: o teste está testando comportamento já existente.
Corrigir o teste antes de continuar.

## Onde se aplica neste projeto

- Parsing de `HookPayload` em `HookIPCServer.swift`
- Lógica de estado em `SessionManager.swift`
- Validação de input em `HookHandler.swift`
- Qualquer função pura nos Models

Não se aplica: SwiftUI views (usar `RenderPreview` via Xcode MCP), protótipos exploratórios.

## Racionalizações comuns

| Racionalização | Realidade |
|---|---|
| "Vou escrever os testes depois para verificar" | Testes depois passam imediatamente — provam nada |
| "Já testei manualmente todos os casos" | Ad-hoc ≠ sistemático. Não roda de novo quando código muda. |
| "É simples demais para precisar de teste" | Código simples quebra. Teste leva 30 segundos. |
| "Já gastei X horas, deletar é desperdício" | Sunk cost. Manter código sem teste real é dívida técnica. |
| "TDD vai me atrasar" | TDD é mais rápido que debugar em produção. |

## Hard rule

Código escrito antes do teste: deletar e recomeçar.
Sem exceções — sem "usar como referência", sem "adaptar enquanto escreve o teste".

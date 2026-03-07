# Explore: MCP Preflight e Session-Type em Skills

## Pergunta reframeada

Como tornar o estado do Xcode MCP uma pre-condicao explicita e verificada nos pontos de
transicao do workflow (start-feature, /clear, handover), em vez de um bloqueio silencioso
descoberto mid-session — sem modificar o comportamento do Claude Code core?

## Premissas e o que nao pode ser

- **Premissa 1:** `/clear` e sempre seguro de fazer a qualquer momento
  — falsa: `/clear` destroi conexoes MCP que so reconectam no proximo startup
- **Premissa 2:** MCP pode ser reconectado mid-session
  — impossivel arquiteturalmente (confirmado por issues abertas no Claude Code)
- **Premissa 3:** Skills sao agnosticas ao estado do ambiente
  — assumpcao atual; precisa mudar
- **Constraint:** Nao ha API para verificar status de MCP server mid-session; so e possivel
  tentar usar a ferramenta e observar se falha
- **Constraint:** A solucao nao pode depender de mudancas no Claude Code core (fora do controle)
- **O que nao pode ser:** documentacao mais clara no CLAUDE.md — documentacao e passiva;
  o usuario precisa lembrar de ler. Todos os sistemas maduros (K8s, IntelliJ, GitHub Actions)
  tornam a pre-condicao **ativa** — o sistema para e explica, nao o usuario que lembra.

## Mapa do espaco

**Sistemas de desenvolvimento com pre-condicoes de ambiente como first-class concept:**
- VS Code `when` clauses + `activationEvents`: comandos ficam cinza (disabled) ate
  o ambiente estar pronto; o componente declara `"enablement": "debuggersAvailable"` de
  forma declarativa
- IntelliJ `DumbService`: estado binario formal (smart vs dumb mode); plugins declaram
  `DumbAware` para opt-in em modo degradado enquanto o indice nao esta pronto
- LSP initialize handshake: 3 fases obrigatorias antes de qualquer operacao; "connected"
  nao implica "ready" — ha um gate formal entre os dois estados

**CI/CD com preflight como primitiva:**
- Kubernetes readiness probes: separacao explicita entre started e ready; falha de
  readiness nao e falha de liveness — o pod continua vivo mas para de receber trabalho
- GitHub Actions `needs`: job upstream falha → downstream e skipado com mensagem
  "skipped (upstream failed)", nao com erro enigmatico
- Docker Compose `depends_on: condition: service_healthy`: aguarda healthcheck passar,
  nao apenas o container iniciar

**AI agents com pre-condicoes de sessao:**
- Devin: cada sessao comeca de snapshot limpo + startup commands com timeout por comando;
  agente nao aceita tarefa ate ambiente estar pronto
- GitHub Copilot Coding Agent: `copilot-setup-steps.yml` — workflow obrigatorio que
  pre-instala dependencias antes de qualquer execucao de tarefa
- Claude Code: sem reconnect automatico, sem liveness check (issues abertas desde 2024:
  #30464, #10129, #1026)

## O gap

- Nenhum framework de skills para AI agents trata `/clear` como "session boundary
  com metadados de tipo" — a informacao de "a proxima sessao precisa de MCP" se perde
- Skills atuais nao tem conceito de "sessao Type A (text-only) vs Type B (MCP-dependent)"
- Handoff messages apos `/clear` nao carregam instrucoes de reconnection quando necessario
- MCP Xcode e hard dependency em exatamente dois pontos do workflow inteiro:
  `RenderPreview` em `/design-review` e `BuildProject` em `/ship-feature` passo 0.5
  — todo o resto (planning, editing, validate, checkpoint, close) e completamente MCP-free
- Graceful degradation e assimetrica: build tem fallback natural (`swift build`);
  preview nao tem — bloquear e correto, mas a mensagem precisa distinguir "sem preview
  block" de "sem MCP conectado"

## Hipotese

A solucao tem tres componentes ortogonais que podem ser implementados independentemente:

1. **Session-type classification no handoff:** quando uma skill recomenda `/clear`,
   ela classifica a proxima sessao como Type A (sem MCP) ou Type B (precisa de MCP) e
   inclui instrucoes de reconnection no bloco de handoff quando necessario. Uma linha de
   texto no template do handoff message resolve o problema na fonte.

2. **Preflight probe no inicio de skills MCP-dependentes:** `/design-review` e o
   step de build em `/ship-feature` fazem um probe de capability no topo — antes de
   qualquer trabalho real. Se MCP nao esta disponivel: `BuildProject` degrada para
   `swift build` (silencioso + warning); `RenderPreview` bloqueia com mensagem explicita
   nomeando a acao de remediacao.

3. **Instrucao de pre-requisito em start-feature para features com UI:** se o
   `plan.md` contem mudancas em arquivos SwiftUI, a skill adiciona um aviso no inicio
   da sessao de implementacao: "esta feature inclui mudancas de UI — antes de comecar,
   confirme que `Package.swift` esta aberto no Xcode."

**Como chegamos aqui:**
- Descartado: modificar Claude Code para suportar MCP reconnect — fora do controle
- Descartado: apenas melhorar documentacao no CLAUDE.md — solucao passiva, demonstradamente
  insuficiente (usuario ja leu, ainda esquece)
- Tensao resolvida: "complexidade extra nas skills vs beneficio" — os preflight checks
  sao 2-3 linhas por skill, e o mapeamento mostra que so 2 pontos do workflow sao
  MCP-dependentes; o escopo e minimo

**Stress-test:** a solucao certa e o Claude Code implementar reconnect automatico
(issues #10129, #1026 pedem exatamente isso) — nao adicionar preflight checks nas skills.
Se/quando o reconnect for implementado, os preflight checks viram codigo morto.
Resposta: reconnect nao tem data de implementacao e pode levar meses ou nunca chegar.
Preflight checks custam 1 PR de ~50 linhas e eliminam o problema agora. Sao complementares,
nao concorrentes.

## Proxima acao

**Veredicto:** melhoria em existente — modificacoes em skills existentes do projeto

**Proxima skill:** `/start-feature mcp-session-preflight`

**O que ficou consolidado:**
- MCP Xcode e hard dependency em exatamente 2 pontos: `RenderPreview` e `BuildProject`.
  Tudo mais e MCP-free e pode receber `/clear` livremente.
- `/clear` e uma session boundary de dois tiers: Tier 1 (reasoning quality, melhora com
  clear) e Tier 2 (external connections, destruido pelo clear). Skills precisam tratar
  os tiers separadamente.
- Graceful degradation e assimetrica por design: build degrada para Bash; preview nao
  tem fallback real — bloquear e correto, mas a mensagem precisa ser especifica.

---
Faca `/clear` para limpar a sessao e entao rode a proxima skill com o slug `mcp-session-preflight`.
O contexto esta preservado em `.claude/feature-plans/mcp-session-preflight/explore.md`.

────────────────────────────────────────────────
Cole na nova sessao apos /clear:

Explore "mcp-session-preflight" concluido.
Contexto salvo em: .claude/feature-plans/mcp-session-preflight/explore.md
Proxima skill: /start-feature mcp-session-preflight
────────────────────────────────────────────────

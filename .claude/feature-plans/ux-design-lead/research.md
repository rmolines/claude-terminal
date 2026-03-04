# Research: ux-design-lead

## Descrição da feature

Sistema de design para Claude Terminal: três arquivos de spec UX + skill `/design-review`
que ensina Claude a atuar como head of design. Objetivo: tornar decisões de UX acumulativas
em vez de drift — cada feature deixa uma restrição que governa a próxima.

Problema raiz: Claude começa cada sessão sem contexto de design acumulado. Features são
adicionadas ad-hoc, fluxos não conversam entre si, padrões derivam. O dev não consegue
organizar e transmitir intenção de UX de forma que sobreviva entre sessões.

## Arquivos existentes relevantes

- `ClaudeTerminal/Features/Dashboard/DashboardView.swift` — tela principal; grid adaptativo de agent cards + sidebar TaskBacklog
- `ClaudeTerminal/Features/Dashboard/AgentCardView.swift` — card individual; status dot, CWD, timer, badges, token spend
- `ClaudeTerminal/Features/Dashboard/NewAgentSheet.swift` — sheet de criação de nova sessão de agente
- `ClaudeTerminal/Features/Terminal/AgentTerminalView.swift` — PTY embarcado por agente
- `ClaudeTerminal/Features/Terminal/SpawnedAgentView.swift` — terminal full-window para inspeção
- `ClaudeTerminal/Features/Terminal/QuickTerminalView.swift` — terminal ad-hoc sem task
- `ClaudeTerminal/Features/Terminal/QuickAgentView.swift` — sessão Claude Code ad-hoc sem task
- `ClaudeTerminal/Features/TaskBacklog/TaskBacklogView.swift` — sidebar esquerda, lista ClaudeTasks
- `ClaudeTerminal/Features/HITL/HITLPanelView.swift` — painel NSPanel de aprovação de HITL
- `ClaudeTerminal/Features/Onboarding/OnboardingView.swift` — first-run, setup de hooks
- `ClaudeTerminal/Features/SkillRegistry/SkillRegistryView.swift` — browser de skills instaladas
- `.claude/commands/*.md` — 10 skills de workflow existentes (padrão a seguir)

## Padrões identificados

- Skills são arquivos `.md` com fases numeradas, subagentes paralelos, outputs estruturados
- Skills sempre leem CLAUDE.md + hot files antes de agir
- Skills geram arquivos de saída: discovery.md, research.md, plan.md
- Nenhum spec de UX centralizado existe — decisões espalhadas em feature plans e comentários de código
- Xcode MCP `RenderPreview` disponível (configurado via `make xcode-mcp`) — pode renderizar `#Preview` blocks e retornar imagem

## Dependências externas

- Xcode MCP `RenderPreview` — necessário para review visual na skill; exige `#Preview` blocks nas views
- Nenhuma lib nova — apenas arquivos `.md` e updates em CLAUDE.md

## Hot files que serão tocados

- `CLAUDE.md` — adicionar referência às spec files na tabela de hot files
- `.claude/commands/design-review.md` — NOVO (skill de head of design)
- `.claude/ux-identity.md` — NOVO
- `.claude/ux-patterns.md` — NOVO
- `.claude/ux-screens.md` — NOVO

Nenhum desses é hot file crítico existente — zero risco de conflito ou regressão.

## Riscos e restrições

- **RenderPreview exige `#Preview` blocks**: telas sem preview block são invisíveis para Claude.
  A skill deve identificar onde faltam previews e incentivar sua criação.
- **Limite de contexto**: os 3 arquivos de spec devem caber junto com código sendo revisado.
  Limites recomendados: ux-identity.md ≤ 600 palavras, ux-patterns.md ≤ 80 padrões (decision table),
  ux-screens.md ≤ 20 linhas por tela.
- **Spec viva, não arqueologia**: o conteúdo inicial descreve *intenção*, não estado atual da
  implementação. Gaps entre spec e código são drift a ser corrigido, não erro da spec.
- **Manutenção**: a skill deve instruir Claude a escrever de volta para ux-patterns.md
  quando descobrir novos padrões — com confirmação do dev antes de commitar.
- **Curly quotes em Swift**: não aplicável (arquivos são .md, não .swift).

## Insight principal (first-principles, --novel)

O problema é tornar intenção de design durável entre sessões stateless. Solução:
**sistema de invariantes de UI** — regras falsificáveis (não prosa aspiracional) que Claude
pode verificar mecanicamente.

Análogos estruturais:
- **Arquitetura de edifícios**: brief (intenção) + código de obras (constraints) + plantas por cômodo (per-screen)
- **Direção teatral**: "conceito de produção" — toda decisão de staging é avaliada contra ele
- **Sistemas distribuídos**: invariantes que devem ser verdadeiros em todos os estados, independente de operações

Consequência prática para o formato da spec:
- `ux-identity.md`: constraints de experiência, não aspirações de estética
- `ux-patterns.md`: decision table (`When / Then / Because / Screens / Status`), não prosa
- `ux-screens.md`: contrato de intenção por tela, não descrição da implementação atual

## Fontes consultadas

Raciocínio de primeira ordem (--novel ativo) — sem URLs externas.

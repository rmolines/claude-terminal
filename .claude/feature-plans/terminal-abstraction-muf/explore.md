# Explore: Claude Terminal como Abstração Completa do CLI

## Pergunta reframeada

Como evoluir Claude Terminal de Mission Control para agentes para a interface que abstrai todas
as interações do dev com o `claude` CLI — e como operacionalizar "Minimum Usable Feature" (MUF)
como critério de planejamento para chegar lá com milestones de impacto crescente e verificável?

## Premissas e o que não pode ser

- **Premissa implícita 1**: "Abstrair todas as interações" é uma direção estratégica, não um estado
  final de um milestone. O espaço de interações é exaustivo (9 grupos, ~30 interações mapeadas).
- **Premissa implícita 2**: "Usável" precisa ser definido comportamentalmente — não "a feature está
  implementada", mas "o dev parou de abrir o terminal para fazer isso".
- **Premissa implícita 3**: MUF pressupõe que existe uma unidade de valor menor que MVP que já muda
  comportamento real — mas só se o critério de "usável" for binário e mensurável.
- **Constraint**: Não pode ser outro Warp/Cursor/Windsurf — eles já existem e resolvem orquestração
  dentro dos seus próprios silos. O valor defensável de Claude Terminal é ser nativo macOS,
  externo ao silo do Claude CLI, tratando cada sessão como entidade com ciclo de vida.
- **Constraint**: Não pode ser "um terminal com UI" — o terminal já existe. O valor está fora dele.
- **Constraint**: MUF mal definido vira MVP disfarçado. O critério precisa ser: "qual ação o usuário
  deixa de fazer no terminal quando este milestone estiver completo?"

## Mapa do espaço

**Abstração de terminais / AI-native IDEs (silos internos):**
- Warp 2.0 ("ADE"): Block como unidade de abstração, agentes com controle total do terminal,
  SWE-bench/Terminal-Bench. Limitação: cloud-only, sem hooks externos.
  ([Warp Agents](https://www.warp.dev/agents))
- Cursor 2.0: Subagents paralelos dentro de uma sessão. Nenhuma observabilidade externa.
  ([Cursor Product](https://cursor.com/product))
- Windsurf/Cognition: Cascade Memory + multi-file edits. Idem — agente dentro do IDE.
  ([Windsurf](https://windsurf.com/editor))

**Mission Control para agentes (mais próximo da visão):**
- GitHub Copilot Mission Control: N agentes em paralelo, status por task (não por conversa),
  steering mid-run via chat. Limitação: web-only, HITL via PR review (não real-time), acoplado
  ao GitHub. ([Copilot Mission Control](https://github.blog/ai-and-ml/github-copilot/how-to-orchestrate-agents-using-mission-control/))
- VS Code Multi-Agent Sessions (1.107+): "Agent Sessions view" com agentes locais + cloud.
  Nativo ao VS Code, não standalone. ([VS Code Multi-Agent](https://code.visualstudio.com/blogs/2026/02/05/multi-agent-development))

**Analogias de outros domínios:**
- Bloomberg Terminal/ASKB: "blotter" como artefato central — mesmo schema por linha, leitura
  periférica de N posições simultâneas. ([ASKB](https://www.bloomberg.com/professional/insights/press-announcement/meet-askb-a-first-look-at-the-future-of-the-bloomberg-terminal-in-the-age-of-agentic-ai/))
- incident.io Decision Flows: HITL com contexto embedded no approval card, decision queue com
  prioridade. ([Decision Flows](https://help.incident.io/articles/9192553935-decision-flows))
- PM2/pm2.web: log como pull, não push — você abre o log quando algo chama atenção.
  ([pm2.web](https://github.com/oxdev03/pm2.web))

**Teoria de planning:**
- Kniberg Earliest Testable/Usable/Lovable (2016): "Usable" = early adopters usam de verdade;
  distingue de "Testable" (gera feedback) e "Lovable" (usuários recomendam).
  ([Kniberg ETU/L](https://blog.crisp.se/2016/01/25/henrikkniberg/making-sense-of-mvp))

## O gap

- **Nenhum produto trata o agente como entidade com ciclo de vida** (fase, tokens, última ação,
  HITL pendente) rastreável fora do próprio tooling que o executa.
- **Nenhum produto implementa HITL como momento de maior valor** com contexto embedded
  suficiente para decidir sem sair do fluxo (incident.io pattern). Todos tratam aprovação como
  interrupção, não como o produto central.
- **A combinação de 3 ingredientes** (Claude Code hooks + socket local + UX nativa macOS) só ficou
  disponível em 2025 — nenhum produto aproveitou ainda. Esse timing é a janela de oportunidade.
- **MUF como critério de planning** não existe operacionalizado em nenhum workflow de desenvolvimento
  que conhecemos — existe como conceito (Kniberg), não como critério concreto em ritos.

## Hipótese

Claude Terminal não é um dashboard de monitoramento com aprovação como side feature — é um
**sistema de decisão que usa monitoramento como contexto**. O frame correto é incident.io, não
Grafana. O HITL approval é o momento de maior valor do produto; tudo o mais (tokens, fase, output)
é contexto que torna essa decisão mais rápida e mais segura.

O roadmap de milestones MUF-first, ordenado pela taxonomia de frequência × urgência
(Q1 → Q2 → Q3 → Q4), é o caminho de menor risco para máximo impacto: cada milestone entrega
um "behavioral shift" verificável — uma ação que o dev para de fazer no terminal. O critério
não é "feature entregue", é "terminal fechado para essa ação".

**Como chegamos aqui:**

- **O que foi descartado**: Roadmap ordenado por complexidade técnica ou por "completude de UI".
  A taxonomia de interações mostra que o dev não liga para completude — liga para o que o tira
  do terminal primeiro.
- **Tensão resolvida**: MUF vs. MVP não é oposição — é granularidade. MVP define completude por
  features entregues. MUF define completude por comportamentos eliminados. Podem coexistir se
  o critério de verificação for explícito em cada milestone.
- **O que a analogia de incident.io resolveu**: A questão "qual é o produto central?" estava
  respondida de forma errada como "monitoring dashboard". A resposta correta é "decision system".
  Isso reorganiza a hierarquia de features: o que serve a decisão HITL vem antes do que serve
  a observação passiva.

**Stress-test:** O argumento mais forte contra é a premissa de que o dev usa Claude Code em
sessões que geram HITL frequente o suficiente para justificar um app separado. Se o padrão de
uso real for "agente roda em background com `--dangerously-skip-permissions` e raramente pede
aprovação", então Q1 vira Q3 (baixa frequência) — e o produto central perde o gatilho de uso
diário. Esse risco só é verificável empiricamente com o próprio dev usando o app por uma semana.

## Mapa de interações (taxonomia Q1–Q4)

Derivado da análise first-principles. Usado como critério de ordenação de milestones.

| Quadrante | Definição | Interações-chave |
|---|---|---|
| **Q1** — Alta freq + Alta urgência | Aha moment + daily trigger | HITL approve/reject, detectar agente preso |
| **Q2** — Alta freq + Baixa urgência | Daily driver, razão para ficar | Output em tempo real, tokens, fase da skill, invocar skill, backlog de tasks |
| **Q3** — Baixa freq + Alta urgência | Panic paths — raramente ocorre, custo alto se falhar | Cancelar agente, configurar permissões, setup inicial |
| **Q4** — Baixa freq + Baixa urgência | Enriquecimento pós-adoção | Histórico de sessões, diff viewer, skills discovery, MCP management |

**Ordem natural de milestones:** Q1 → Q2 → Q3 → Q4.

## MUF operacionalizado nos ritos

### Template para sprint.md (adicionar a `/start-milestone`)

```text
## MUF deste milestone

- **Ação que o dev para de fazer no terminal:** [descrição exata]
- **Critério de verificação:** [5 dias úteis sem abrir terminal para fazer X]
- **Features mínimas para atingir o MUF:** [lista]
- **Features enabler** (infra que outra feature precisa): [lista]
- **Features enhancement** (valor incremental, não bloqueia MUF): [lista separada]
```

### Gate em `/validate`

Adicionar ao checklist: "Esse código, se deployado agora, entrega o MUF do milestone?
Se não, o que falta e quanto é?" Não apenas "o código bate com o plan.md?"

### Critério em `/start-feature`

Cada feature deve declarar explicitamente: é MUF-critical, enabler, ou enhancement?
Features enhancement não bloqueiam ship — vão para a lista de Q4 do próximo milestone.

## Próxima ação

**Veredicto:** melhoria em existente — roadmap para Claude Terminal já em produção

**Próxima skill:** `/plan-roadmap`
**Nome sugerido:** `terminal-abstraction-muf`

**O que ficou consolidado:**

- A taxonomia Q1–Q4 é o critério de ordenação de milestones. Não usar complexidade técnica.
- O frame "sistema de decisão + contexto" (incident.io) substitui "monitoring dashboard" como
  modelo mental do produto — essa distinção tem consequências de design em cada tela.
- MUF precisa de critério comportamental explícito por milestone: "ação que o dev para de fazer
  no terminal" — sem isso é MVP com nome diferente.

---

Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `terminal-abstraction-muf`.
O contexto está preservado em `.claude/feature-plans/terminal-abstraction-muf/explore.md`.

────────────────────────────────────────────────
Cole na nova sessão após /clear:

Explore "terminal-abstraction-muf" concluído.
Contexto salvo em: .claude/feature-plans/terminal-abstraction-muf/explore.md
Próxima skill: /plan-roadmap
────────────────────────────────────────────────

# Explore: Workflow Initiation UX for Agent Mission Control

## Pergunta reframeada

Qual é o design certo para uma interface de iniciação de workflows (skills) dentro de uma
dashboard de Mission Control para agentes Claude Code — sem degradar para um terminal
disfarçado ou um form wizard genérico?

## Premissas e o que não pode ser

- **Premissa implícita 1:** Iniciar workflows hoje exige saber o nome da skill e digitá-la
  em um terminal raw — a iniciação está desacoplada da UX de monitoramento
- **Premissa implícita 2:** O gap está na entrada, não no acompanhamento — Claude Terminal já
  tem uma UX de monitoramento funcional
- **Premissa implícita 3:** Uma boa UX de iniciação pode substituir o conhecimento explícito
  das skills para o caso comum
- **Constraint — o que não pode ser:** Uma command palette de texto livre não resolve o problema
  — o "vocabulary problem" (Furnas et al., 1987) mostra que dois usuários concordam no nome
  de um comando com probabilidade < 0.20. Skills têm nomes específicos que o usuário precisa
  memorizar. Isso mantém a barreira de entrada.
- **Constraint — o que não pode ser:** Um form wizard multi-step (Jenkins style) cria overhead
  cognitivo maior que o terminal. A literatura é clara: forms com > 3 campos na iniciação são
  o anti-padrão (CircleCI community feedback, Jenkins cautionary tale).
- **Constraint arquitetural:** Skills são arquivos Markdown sem schema legível pela máquina.
  Não há como gerar um form dinâmico e tipado sem um metadata protocol que não existe hoje.
  Qualquer form de iniciação tem argumentos hard-coded — o que o torna uma abstração frágil
  se as skills evoluírem.

## Mapa do espaço

**Launchers textuais (recall-based):**
- Spotlight, Alfred, VS Code Command Palette — rápidos para experts, floor alto (usuário deve
  saber o que buscar). VS Code separa busca de conteúdo de execução de comando com o prefixo `>`.
- [Philip Davis — Command Palette Interfaces](https://philipcdavis.com/writing/command-palette-interfaces)

**Structured forms (declaration vs trigger time):**
- GitHub Actions `workflow_dispatch` — o melhor exemplo público do split "declarado vs inferido".
  O form tem exatamente os campos que o autor do YAML declarou como variáveis humanas.
- Vercel deploy — colapsa o trigger ao mínimo irredutível: "qual commit ou branch?"
- Jenkins "Build with Parameters" — cautionary tale: decisions de declaration time vazam para
  trigger time → 15 campos obrigatórios → feedback da comunidade pedindo "só clique Go"
- [GitHub Actions manual triggers](https://github.blog/changelog/2020-07-06-github-actions-manual-triggers-with-workflow_dispatch/)

**Pre-populated action surfaces (contextual, proactive):**
- Cursor background agents — lista de sessões em background com status; iniciar = Ctrl+E + pick model
- GitHub Mission Control / Agent HQ — dashboard dedicado para agentes; entrada via issue + "Assign to Copilot"
- Linear for Agents — issues são o trigger canônico; agentes são assignees como humanos
- [GitHub Copilot Mission Control](https://github.blog/changelog/2025-10-28-a-mission-control-to-assign-steer-and-track-copilot-coding-agent-tasks/)

**Text-to-plan (zero-friction entry, AI generates structure):**
- Copilot Workspace — texto livre → Spec (current/desired state editável) → Plan → código
- Devin 2.0/2.2 — text box + optional issue link; o agente infere tudo do contexto do repo
- Padrão notável: nenhuma dessas ferramentas usa form estruturado com múltiplos campos;
  a estrutura é gerada pela IA, não preenchida pelo usuário
- [Copilot Workspace user manual](https://github.com/githubnext/copilot-workspace-user-manual/blob/main/overview.md)

**Session launchers (terminal-side):**
- iTerm2 Profiles — intent encoded at definition time; lançar = uma seleção
- zellij-sessionizer — session = pick a folder; nome, layout, comando derivados da pasta
- Mais próximo analogamente do problema: "start an agent session for this task" onde a task
  já carrega o contexto necessário
- [iTerm2 Profiles](https://iterm2.com/documentation-preferences-profiles-general.html)

## O gap

- Claude Terminal é o único contexto onde **skills têm assinatura conhecida** (nome + argumento único)
  E **o estado de workflow está persistido** (ClaudeProject.workflowStates) — nenhuma outra ferramenta
  tem ambos.
- As ferramentas de AI (Copilot Workspace, Devin) geram estrutura a partir de texto livre porque não
  têm skills pré-definidas. Claude Terminal tem — as skills já são o plano. Não há necessidade de
  gerar um plano, só de escolher e nomear.
- O gap específico: uma interface que usa workflowStates para **sugerir a skill certa** (em vez de
  exigir que o usuário saiba o nome), pré-preenche o cwd do projeto, e reduz o input ao argumento
  mínimo (nome da feature, tópico do explore).
- Nenhuma ferramenta combina: (a) sugestão contextual de skill + (b) contexto de projeto pre-populated
  + (c) UX nativa macOS que some depois de lançar.

## Hipótese

A UX certa para iniciar um workflow no Claude Terminal não é um launcher nem um form wizard — é um
**contextual launch sheet** que inverte a ordem de interação: em vez de o usuário escolher uma skill
e preencher campos, o sistema mostra o que o projeto "pede" a seguir (skill sugerida baseada em
workflowStates), pré-preenche o cwd do projeto selecionado, e reduz o input do usuário ao argumento
mínimo (nome da feature, tópico do explore).

A "confirmação de contexto" (branch atual, worktrees existentes para esse projeto, workflow phase)
fica visível como informação de suporte — não como campos a preencher. O Submit não confirma intenção;
confirma contexto. A sheet some imediatamente ao spawnar o PTY e um AgentCard sintético aparece no
dashboard.

**Como chegamos aqui:**
- Descartado: command palette livre (vocabulary problem — o usuário precisaria saber o nome da skill
  com precisão; probabilidade de acerto < 20%)
- Descartado: text-to-plan (Copilot Workspace style) — as skills já são o plano estruturado;
  gerar um plano a partir de texto livre seria redundante e mais lento
- Resolvido: tensão "app como observer vs app como initiator" — a sheet é framing de "passar contexto
  ao Claude Code" (causação do usuário), não "o app lançando um agente" (causação do app). O app
  mantém identidade de observer; a iniciação é explicitamente uma ação do usuário.

**Stress-test:** Skills não têm schema legível pela máquina. Um form com skill-picker + text field
para argumento é uma abstração frágil: se start-feature ganhar novos parâmetros obrigatórios ou
se uma nova skill de iniciação for criada, o form fica stale silenciosamente. A única defesa é aceitar
que o form é um contrato explícito sobre um conjunto pequeno e estável de skills de iniciação
(start-feature, start-project, explore — 3 skills que existem há meses sem mudança de assinatura),
e tratá-lo como código que evolui junto com as skills — não uma abstração automática.

## Próxima ação

**Veredicto:** melhoria em existente (Claude Terminal já tem o app; a feature adiciona uma surface
de iniciação ao dashboard existente)

**Próxima skill:** `/start-feature --discover workflow-initiation-panel`
**Nome sugerido:** `workflow-initiation-panel`

**O que ficou consolidado:**
- **Constraint de dados:** input mínimo necessário = `{project/cwd, skill, skill_primary_argument}`.
  Branch, workflow phase e worktrees existentes são inferíveis do ClaudeProject e podem ser exibidos
  como contexto de suporte — não campos obrigatórios.
- **Constraint arquitetural:** o app não tem um "launch agent" method no SessionManager — só reage
  a hooks. A iniciação deve spawnar um PTY e escrever a skill como stdin. O `isSynthetic: true`
  pattern já existe para AgentCards pre-hook.
- **Abordagem descartada:** dynamic form generation a partir de skill Markdown (não há schema;
  acoplamento muito frágil para 3 skills estáveis).

---

Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `workflow-initiation-panel`.
O contexto está preservado em `.claude/feature-plans/workflow-initiation-panel/explore.md`.

---

Cole na nova sessão após /clear:

Explore "workflow-initiation-panel" concluído.
Contexto salvo em: .claude/feature-plans/workflow-initiation-panel/explore.md
Próxima skill: /start-feature --discover workflow-initiation-panel

# Explore: Feature Start UX — Worktree Creation and Skill Launch

## Pergunta reframeada

Como o Claude Terminal pode ser o ponto de entrada para começar uma nova feature — desde
criar o worktree até lançar a skill — em vez de ser um observer passivo de worktrees e
sessões já existentes? E como isso é a fundação para gerenciar N features em paralelo com
segurança e visibilidade?

## Premissas e o que não pode ser

- **Premissa 1:** "Melhorar a UX de worktrees" significa adicionar criação, não apenas
  melhorar a visualização da lista.
- **Premissa 2:** Skills e Worktrees estão em abas separadas hoje, mas representam a
  mesma unidade de trabalho vista por ângulos diferentes — separá-los é o problema.
- **Premissa 3:** O usuário quer que o app seja o ponto de entrada, não o Claude Code CLI
  ("entro aqui e começo o trabalho").
- **Premissa 4:** "Rodar skill visualmente" implica que o app tanto lança quanto monitora
  a execução, não apenas sugere o comando para colar no terminal.
- **Constraint — C2 (terminal é read-only):** O app não pode enviar input para terminais
  já abertos. Skill injection só funciona no momento de spawn do PTY, via string de
  comando shell. Isso é uma restrição real do design, não só da implementação atual.
- **Constraint — sequência é rígida:** `worktree no disco → PTY no worktree → skill no PTY`.
  Skill não pode vir antes do worktree. A skill pode criar seu próprio worktree, mas se
  o app criar primeiro, o rastreamento de fase (WorkflowPhase) funciona desde o início.
- **O que não pode ser a solução:** Só adicionar um botão "+" sem continuar o fluxo; ou
  deixar a skill criar o worktree (o app só descobre 30s depois via poll — perdendo
  visibilidade durante toda a execução da skill).

## Mapa do espaço

**Git GUIs (Tower, GitKraken, GitLens/VS Code):**
- Formulário de 2 campos: branch + path. Um campo ideal: nome da feature, resto derivado.
- Convenção universal de path: `../repo-branch-name` (sibling) ou `.claude/worktrees/<name>`.
- Post-criação = navegação para o novo worktree É a confirmação. Sem toast, sem modal de sucesso.
- GitLens colapsa "nova branch" + "novo worktree" em uma ação só — reconhecido como a UX certa após feedback de usuários.

**GitHub Issues → Create Branch (analogia mais próxima):**
- Branch name auto-derivado do título da issue (`42-fix-login-crash`), editável.
- Após criação: "Open in Codespace" ou "Checkout locally" (cola os git commands).
- O gap que o GitHub não consegue fechar: o passo local ainda é manual. Claude Terminal fecha esse gap.

**OpenAI Codex (mais próximo ao modelo agent-native):**
- Task → seleciona "Worktree" mode → pick base branch → submit → agente roda.
- O app gerencia `git worktree add` internamente. Usuário nunca digita path.
- Botão "Hand off" quando o agente termina — distinct framing: "agente trabalhou, agora é sua vez".

**Visual skill/command launchers (Raycast, GitHub Actions, VS Code Tasks):**
- Lista com busca first + frecency ranking — não grid.
- Args inline (tab-through) para ≤2 params; form sheet para 3-5 params com defaults.
- Status em 2 camadas: nome da skill + fase atual no card; log streaming expansível por passo.
- HITL: painel flutuante não-bloqueante (já existe no app).

**Parallel work UX (Vercel, Linear, Buildkite, research cognitivo):**
- **Branch name como primary key** em todo lugar — não session ID, não índice numérico.
- Status periférico: cor/badge legível sem precisar ler. VS Code status bar color, GH Actions dots.
- Progressive disclosure: card mostra branch + fase + glifo; hover/click revela detalhe.
- Linear: branch creation → issue muda para "In Progress" automaticamente. Branch é o trigger do state machine.
- Pesquisa cognitiva: 23 minutos para recuperar foco após uma interrupção. O valor do app é colapsar N sessões em 1 superfície de atenção dividida.

## O gap

- **Nenhuma ferramenta fecha o loop completo no native macOS:** Git GUIs criam worktrees mas
  não lançam agentes. Claude Code CLI lança agentes mas não gerencia worktrees visualmente.
  O app tem monitoramento mas não tem criação.
- **O único input não derivável é o nome da feature.** Tudo mais (branch `feature/<name>`,
  path `.claude/worktrees/<name>`, base branch `main`, comando `/start-feature <name>`) pode
  ser auto-computado. O formulário mínimo é um único campo de texto.
- **O estado da skill cria um catch-22:** SkillsNavigatorView só aparece quando há sessão ativa.
  Mas sessões só existem se o usuário criou um worktree manualmente. Não há como "começar do
  app" — o usuário sempre tem que ir ao terminal externo primeiro.
- **Worktrees e Skills tratam a feature como duas coisas separadas** quando são a mesma coisa:
  uma unidade de trabalho com contexto de execução (worktree) e posição no workflow (fase da skill).

## Hipótese

O Claude Terminal está a uma ação de ser o ponto de entrada real para o trabalho de features:
um botão `+` na aba Worktrees que abre uma sheet com um campo de texto (nome da feature),
cria o worktree via `GitStateService`, lança o PTY com `claude` no novo diretório, e
opcionalmente injeta `/start-feature <name>` no spawn. Isso fecha o loop sem mudar a arquitetura
de abas, sem reescrever o monitoring, e sem violar C2.

A feature de "múltiplas features em paralelo" não exige nova arquitetura agora — ela exige
que o primeiro worktree possa ser criado do app. A partir daí, a infraestrutura já suporta
N sessões simultâneas (ZStack de terminais, SessionStore como source of truth).

**Como chegamos aqui:**

- Descartado: fazer a skill criar o worktree (o app só descobre via poll 30s depois —
  perde rastreamento de fase durante o trabalho mais importante).
- Descartado: redesign de abas para unificar Worktrees + Skills (elas têm jobs diferentes
  e já funcionam bem para monitoramento; o problema é só a criação).
- Resolvido: a tensão entre "skill injection" (app envia comando) e C2 (terminal read-only)
  se dissolve quando o injection acontece no momento de spawn, não depois.

**Stress-test:** O `/start-feature` skill já cria o worktree por conta própria quando
executado do `main`. Se o dev continua usando o CLI diretamente (como hoje), esse fluxo
nunca é usado e o investimento é desperdiçado. A hipótese pressupõe que o usuário quer
o app como ponto de entrada — mas hoje ele está treinado a ir ao terminal primeiro. A
mudança de hábito pode ser mais difícil do que a mudança de UI.

## Próxima ação

**Veredicto:** Melhoria em existente — feature cirúrgica no app atual.

**Próxima skill:** `/start-feature --deep`

**Nome sugerido:** `feature-start-ux`

**O que ficou consolidado:**

- O único input não-derivável é o nome da feature. Formulário mínimo = 1 campo.
- Model A (app cria worktree → lança PTY → injeta skill) é correto e suportado pela
  arquitetura atual (GitStateService, displayPath, ZStack de terminais).
- O constraint C2 + skill injection: injection só funciona no momento de spawn. Se não
  auto-injetar, o usuário digita 1 linha já conhecida — aceitável como fallback.
- "Múltiplos features em paralelo" é uma consequência natural de criar o primeiro worktree
  do app — a infra já suporta N sessões. Não é uma feature separada no core.

---

Faça `/clear` para limpar a sessão e então rode `/start-feature --deep feature-start-ux`.
O contexto está preservado em `.claude/feature-plans/feature-start-ux/explore.md`.

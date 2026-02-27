# Project Brief — Claude Terminal
_Gerado em: 2026-02-27_

## Problema
Um dev usando múltiplas sessões de Claude Code em paralelo não tem interface projetada para esse workflow. Hoje: N janelas de terminal empilhadas, zero contexto sobre o que cada agente está fazendo, ideias de features perdidas entre sessões, sem forma centralizada de aprovar pedidos de HITL sem quebrar o foco. O dev atua como PM/CEO de uma squad de agentes, mas não tem um Mission Control — tem um amontoado de terminais de texto.

## Usuário primário
Solo developer que usa Claude Code como força multiplicadora — opera como PM/CEO de uma squad de agentes de IA. Usa skills estruturados (`start-feature`, `fix`, `start-project`) como protocolo de trabalho. Roda múltiplos agentes em paralelo via abas do Warp hoje. Nível técnico alto, usa macOS como plataforma principal, familiar com git worktrees e Claude Code hooks.

## Usuário secundário
Não existe no v1. Produto pessoal open source que pode crescer para outros Claude Code power users.

## Proposta de valor central
Mission Control para uma squad de agentes Claude Code: criar tasks, acompanhar progresso em tempo real (tokens, fase do plano, fase da skill, sub-agentes em background), aprovar pontos HITL direto do menu bar, nunca perder uma ideia de feature. O terminal fica escondido — o usuário vive no app.

## Métrica de sucesso
- 90 dias: usado pelo criador todo dia + 100 stars no GitHub
- 1 ano: 1.000 stars, 5+ contribuidores, 50+ devs usando Claude Code intensivamente

## MVP — Dentro do escopo

### Core: Orquestração de agentes
- Dashboard principal mostrando todos os agentes ativos/pausados/concluídos
- Criar nova task (feature/fix) → app roda `start-feature <nome>` ou `fix <nome>` via Claude Code
- Setup automático de hooks em `~/.claude/settings.json` (zero config manual pelo usuário)
- Cada agente exibe em tempo real:
  - Tokens consumidos + custo estimado ($)
  - Sub-agentes rodando em background
  - Fase atual: criação do plano vs execução
  - Progresso no plano (step N/M)
  - Fase atual da skill (`start-feature` → Plan → Execute → Ship)
  - Status: `rodando` / `aguardando input` / `concluído` / `bloqueado`

### Core: Human-in-the-loop
- Quando agente precisa de aprovação: badge no menu bar + notificação nativa macOS
- Painel de aprovação inline: mostra o que o agente quer fazer + contexto resumido
- Aprovar/rejeitar com uma tecla sem sair do contexto atual

### Core: Backlog de tasks
- Lista persistente de features/fixes/projetos (SwiftData local)
- Criar task → vincular a agente ativo
- Estado de cada task sincronizado com estado do agente

### UI
- App com janela própria (dashboard principal)
- Menu bar app com badge numérico ("N aguardando atenção")
- Terminal opcional: o usuário pode expor a sessão raw do Claude Code se quiser inspecionar
- Keyboard-first: toda ação principal tem atalho

## Fora de escopo explícito (v1)
- SSH / VPS / secrets management — complexidade de infra desnecessária no v1
- Arquitetura remota (agentes rodando em servidor) — produto diferente, 6+ meses de trabalho
- Multi-usuário / auth / billing — é open source, sem receita planejada
- Windows / Linux — macOS-only, sem compromisso de cross-platform
- Integração com GitHub Issues / Linear / Jira — fricção de autenticação, fora do foco
- Construir emulador de terminal próprio — usar SwiftTerm, não reinventar

## Modelo de negócio
Open source (MIT ou Apache 2.0). Sem monetização planejada para v1. O valor é pessoal (alavancar o criador) e comunitário (outros devs que usam Claude Code intensivamente). Eventual monetização poderia ser cloud sync / hosted version, mas fora do escopo agora.

## Stack técnico inicial

| Camada | Escolha | Justificativa |
|---|---|---|
| Linguagem | Swift 6 | Nativo macOS, acesso a todas as APIs, DMG notarizado |
| UI | SwiftUI + AppKit | Dashboard moderno + NSPanel floating, NSStatusItem menu bar |
| Terminal engine | SwiftTerm | PTY management pronto, VT100 completo, NSView reutilizável |
| Parsing de agentes | Claude Code hooks + `--output-format stream-json` | Interface oficial e estável — não parsear ANSI |
| Persistência | SwiftData (macOS 14+) | Zero boilerplate, integrado com SwiftUI |
| Notificações | UNUserNotificationCenter | Nativo, actionable (aprovar/rejeitar sem abrir o app) |
| Distribuição | DMG notarizado, fora da App Store | PTY exige ausência de sandbox; App Store incompatível |

## Decisões técnicas antecipadas

**Hooks como protocolo de comunicação (não parsear ANSI)**
Os hooks do Claude Code (`PreToolUse`, `PostToolUse`, `Notification`, `Stop`) são a única interface estável entre o app e o Claude Code. O app configura automaticamente `~/.claude/settings.json` para chamar um helper binary que comunica via IPC local. Nunca depender de regex em ANSI output.

**Helper binary separado**
O app principal (SwiftUI) não pode receber callbacks de hooks diretamente (não está na linha de execução do claude). Precisa de um helper CLI (`claude-terminal-helper`) que os hooks chamam, e que comunica com o app via XPC ou socket local. Esse helper é instalado automaticamente pelo app.

**Worktrees como unidade de isolamento**
Cada task/agente cria um git worktree isolado. Isso evita conflitos entre agentes e permite rodar N sessões no mesmo repositório em paralelo. O app gerencia a criação/remoção de worktrees automaticamente.

**SwiftData para persistência local**
Tasks, agentes, histórico de tokens, aprovações — tudo local. Sem backend. Funciona offline. Dados vivem em `~/Library/Application Support/ClaudeTerminal/`.

## Registro de riscos

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Anthropic lança UI oficial para múltiplos agentes | Média-Alta | Alto | Focar nos skills específicos do usuário (start-feature/fix) como diferencial; comunidade open source como moat |
| Claude Code muda formato de output (quebra hooks) | Média | Médio | Depender apenas dos hooks oficiais, nunca de ANSI parsing |
| Apple integra Claude nativo no macOS (além do Xcode) | Baixa | Alto | Escopo diferente: gestão de CLI sessions ≠ IDE integration |
| Projeto sem contribuidores após lançamento | Alta | Baixo | É ferramenta pessoal — funciona mesmo sem comunidade |
| macOS 14+ required quebra adoção | Baixa | Baixo | SwiftData exige 14+; usuário de Claude Code intensivo tipicamente está em versão atual |

## Anti-patterns a evitar
- **Não construir terminal emulador**: SwiftTerm resolve isso. Foco na camada de orquestração.
- **Não interceptar OAuth/API tokens**: os processos são terminais locais reais rodando `claude`. Zero interceptação de API.
- **Não parsear ANSI**: hooks são a interface correta. ANSI parsing quebra com qualquer atualização do Claude Code.
- **Não ser o Warp**: Warp é genérico. Este produto é opinionado sobre Claude Code e os skills específicos do usuário.
- **Não adicionar features antes de usar diariamente**: v1 = o criador usa todo dia. Só então expandir.
- **Não adicionar backend antes de precisar**: SwiftData local é suficiente. Backend cria dependência de infra.

## Referências e aprendizados

| Projeto/Produto | O que aprender | O que evitar |
|---|---|---|
| cmux (manaflow-ai/cmux) | Swift + libghostty + notificações via OSC; prova que o stack funciona | Não tem gestão de tasks/HITL/tokens — o que você vai adicionar |
| Claude Squad (smtg-ai/claude-squad) | Worktree isolation automático por agente; TUI funcional | Interface TUI sem widget compacto; sem gestão de features |
| Warp 2.0 | Block structure; mode locking; multi-agent monitoring | Login obrigatório; genérico demais; sem tmux; paywalls progressivos |
| Linear | 4 estados máximos; keyboard-first; performance como feature primária; opinionated | Não adaptar para contexto de agentes sem remover o que não faz sentido |
| Fig (adquirida pela Amazon) | Não encontrou modelo de negócio; foi absorvida | — |
| Hyper (Vercel) | Electron para terminal = erro de framework | Sempre priorizar nativo para terminal |

## Próximos passos
Fase 1 — Research técnica detalhada baseada neste brief.
Rode `/start-project` novamente para continuar.

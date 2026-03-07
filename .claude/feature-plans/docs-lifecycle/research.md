# Research: docs-lifecycle

## Descrição da feature

Eliminar LEARNINGS.md (739 linhas append-only) e reestruturar o ciclo de vida de documentação
de conhecimento: (1) migrar conteúdo do LEARNINGS.md para CLAUDE.md armadilhas ou auto-memory
estruturado, (2) reestruturar auto-memory MEMORY.md em seções tipadas com overflow para topic
files, (3) atualizar close-feature para rotear conhecimento diretamente (sem LEARNINGS.md),
(4) atualizar start-feature Passo B.4 para ler seções estruturadas em vez de dump completo.

## Arquivos existentes relevantes

- `LEARNINGS.md` — 739 linhas, append-only, formato `## YYYY-MM-DD — título`. Entradas mistas:
  gotchas Swift/SwiftUI, CI/GitHub Actions, padrões de workflow. Algumas são duplicatas do que
  já está em CLAUDE.md armadilhas. Esta é a fonte primária de migração.
- `~/.claude/projects/-Users-rmolines-git-claude-terminal/memory/MEMORY.md` — auto-memory de
  ~200 linhas. É o arquivo que Claude lê/escreve automaticamente em cada sessão. Atualmente já
  tem seções mas sem tipagem formal (## Status, ## HITL Architecture, ## Swift 6 Gotchas, etc.).
  Este é o destino principal da migração.
- `~/.claude/projects/-Users-rmolines-git-claude-terminal/memory/` — diretório onde os topic
  files serão criados (swift-concurrency.md, swiftdata.md, build-system.md, etc.)
- `.claude/commands/close-feature.md` — 333 linhas. **Passo 1d** escreve em LEARNINGS.md;
  **Passo 1e** propõe armadilhas para CLAUDE.md. Passo 1d precisa ser substituído.
- `.claude/commands/start-feature.md` — **Passo B.4** lança subagente Explore para ler
  LEARNINGS.md inteiro e identificar learnings relevantes ao plan.md. Precisa ser atualizado
  para ler seções tipadas do MEMORY.md.
- `memory/MEMORY.md` (no git repo, raiz do projeto) — 45 linhas, remanescente do template
  kickstart sobre claude-kickstart. Irrelevante para esta feature; pode ser ignorado.

## Padrões identificados

**Separação de camadas validada por pesquisa (arXiv 2602.20478, Codified Context):**

```text
Hot  → CLAUDE.md armadilhas — alta confiança, sempre-relevante, curto. Nunca cresce acima
        de ~30-40 entradas; além disso extrair para topic files.
Warm → MEMORY.md auto-memory — decisões, padrões, gotchas médios. Cap de 200 linhas.
        Overflow automático para memory/*.md topic files com links.
Cold → memory/*.md topic files — detalhe por domínio (swift-concurrency, swiftdata, etc.)
        Carregados sob demanda via link no MEMORY.md.
Episódico → HANDOVER.md, plan.md, sprint.md — descartados/arquivados após a feature.
```

**Critério de roteamento para migração do LEARNINGS.md:**

| Condição da entrada | Destino |
|---|---|
| Pitfall de alta confiança, always-relevant, não está em CLAUDE.md ainda | CLAUDE.md armadilhas |
| Duplicata do que já existe em CLAUDE.md | DESCARTAR |
| Decisão arquitetural ou padrão confirmado | MEMORY.md `## Decisions` ou `## Patterns` |
| Gotcha técnico de domínio específico (Swift concurrency, SwiftData, etc.) | topic file |
| Workaround de Swift 6 / compilador | memory/swift-concurrency.md |
| Padrão SwiftData (schema, migration, context) | memory/swiftdata.md |
| Pipeline de build, notarização, CI | memory/build-system.md |
| IPC, sockets, SecureXPC | MEMORY.md `## Architecture` (já existe) ou topic file |
| Observação desatualizada, já resolvida, sem valor futuro | DESCARTAR |
| Nota sobre workflow (skills, git, worktrees) | MEMORY.md `## Workflow` |

**Formato das seções tipadas no MEMORY.md:**

```markdown
## Decisions
<!-- Decisões arquiteturais confirmadas. Ex: "SwiftTerm vs xterm.js" -->

## Patterns
<!-- Padrões de código confirmados no projeto. Ex: "One DispatchQueue per TerminalView" -->

## Gotchas
<!-- Armadilhas de nível médio. Alta confiança mas não merece entrar no CLAUDE.md hot -->

## Architecture
<!-- Estado atual da arquitetura — atualizar quando mudar componentes principais -->
```

**Passo B.4 atualizado — leitura seletiva:**
Em vez de `lançar subagente Explore para ler LEARNINGS.md inteiro`, o passo passa a:
"Ler seções relevantes do MEMORY.md (`## Decisions`, `## Patterns`, `## Gotchas`).
Se existirem topic files linkados relacionados ao domínio da feature, ler esses arquivos.
Incorporar ajustes e adicionar seção `## Learnings aplicados` no plan.md."

## Dependências externas

Nenhuma. Feature é puramente de reorganização de arquivos de texto e atualização de skills.

## Hot files que serão tocados

- `LEARNINGS.md` — arquivo principal a ser migrado e deletado
- `~/.claude/projects/.../memory/MEMORY.md` — auto-memory a ser reestruturado
- `.claude/commands/close-feature.md` — Passo 1d substituído, roteamento adicionado
- `.claude/commands/start-feature.md` — Passo B.4 atualizado

Nenhum desses é hot file Swift do CLAUDE.md (source code). Zero risco de conflito de agentes.

## Riscos e restrições

**Perda de conteúdo na migração:**
LEARNINGS.md tem 739 linhas. A migração é one-shot — criar backup (`LEARNINGS.md.bak`) antes
de começar. Algumas entradas serão descartadas deliberadamente (duplicatas do CLAUDE.md).
O critério de descarte precisa ser aplicado consistentemente para evitar acumular MEMORY.md
com entradas que já estão no CLAUDE.md hot layer.

**MEMORY.md auto-memory estoura o cap durante migração:**
Ao consolidar 739 linhas → seções tipadas, muitas entradas vão para topic files.
Estratégia: criar topic files `memory/swift-concurrency.md`, `memory/swiftdata.md`,
`memory/build-system.md` ANTES de migrar, para ter destino pronto. MEMORY.md recebe
apenas entradas não-domínio-específicas + links para os topic files.

**Roteamento subjetivo no close-feature:**
Pedir ao agente "isso vai para CLAUDE.md ou MEMORY.md?" é julgamento. Mitigação: critério
binário explícito na skill — "alta confiança + sempre-relevante = CLAUDE.md; tudo mais = MEMORY.md
ou topic file". Sem gradação.

**start-feature B.4 sem LEARNINGS.md existente:**
Passo B.4 atualizado deve ser condicional: `se MEMORY.md existir: ler seções relevantes`.
Não deve quebrar em projetos onde MEMORY.md ainda não está reestruturado.

**Aviso de longo prazo (fora do escopo):**
A tabela "Armadilhas conhecidas" no CLAUDE.md vai crescer indefinidamente — ela é "episódica
por natureza mas vive na camada hot" (Pattern 3, Codified Context). Isso é um problema para
uma feature futura de extração; não está no escopo desta.

## Fontes consultadas

- arXiv 2602.20478 — Codified Context: Infrastructure for AI Agents in a Complex Codebase
- arXiv 2511.12884 — Agent READMEs: Empirical Study of Context Files
- arXiv 2512.13564 — Memory in the Age of AI Agents (January 2026)
- Anthropic Engineering: Effective context engineering for AI agents
- Anthropic Engineering: Equipping agents with Agent Skills

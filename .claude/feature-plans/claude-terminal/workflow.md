# Workflow Map — Claude Terminal

Mapa completo das skills, quando usar cada uma, e como se conectam.

---

## Fluxo visual

```
ESTRATÉGICO (uma vez por projeto/milestone)
──────────────────────────────────────────
  /refine-idea → /start-project → /plan-roadmap → /start-milestone

TÁTICO (por feature)
──────────────────────────────────────────
  /start-feature → [implementar] → /validate → /ship-feature → /close-feature

ORIENTAÇÃO (qualquer momento)
──────────────────────────────────────────
  /project-compass

AD-HOC (feature sem roadmap)
──────────────────────────────────────────
  /start-feature <nome> → [implementar] → /ship-feature → /close-feature
```

---

## Tabela de skills

| Skill | Quando usar | Input | Output | Próxima skill |
|-------|-------------|-------|--------|---------------|
| `/refine-idea` | Ideia nova ou vaga | Descrição livre | Brief estruturado | `/start-project` |
| `/start-project` | Criar repositório do zero | Brief aprovado | Repo + skills especializadas | `/plan-roadmap` |
| `/plan-roadmap` | Definir milestones e features | Projeto existente | `roadmap.md` atualizado | `/start-milestone` |
| `/start-milestone` | Começar um novo milestone | `roadmap.md` | `<M>/sprint.md` com features | `/start-feature` |
| `/start-feature` | Começar implementação de uma feature | Nome (ou próxima do sprint.md) | Worktree + `plan.md` | `/validate`, `/ship-feature` |
| `/validate` | Verificar alinhamento antes de fazer PR | Branch com código | Relatório drift/cobertura | `/ship-feature` ou correção |
| `/ship-feature` | Abrir PR após implementação | Código pronto | PR aberto no GitHub | `/close-feature` |
| `/close-feature` | Limpar após PR merged | PR merged | Worktree removido + docs atualizados | `/project-compass` |
| `/project-compass` | "Onde estou? O que fazer agora?" | Nenhum (lê git + sprint.md) | Relatório de estado + próxima ação | Varia |
| `/handover` | Passar contexto para outro agente | Branch atual | Resumo de estado da sessão | — |

---

## Hierarquia de dois níveis

### Estratégico (global: `~/.claude/commands/`)

Skills de criação de projetos. Usadas uma vez por projeto ou milestone.

- `/refine-idea`
- `/start-project`
- `/plan-roadmap`

### Tático (por projeto: `.claude/commands/`)

Skills de workflow, especializadas para este projeto. Usadas por feature.

- `/start-feature`
- `/validate`
- `/ship-feature`
- `/close-feature`
- `/start-milestone`
- `/project-compass`
- `/handover`

---

## Estrutura de diretórios

```
.claude/feature-plans/claude-terminal/
  project-brief.md        ← visão geral do produto
  research.md             ← pesquisa de stack e alternativas
  roadmap.md              ← milestones e features planejadas
  workflow.md             ← este arquivo: mapa de skills
  M1/
    sprint.md             ← features do M1
    <feature-done>/       ← dirs de features concluídas (referência)
      plan.md
  M2/
    sprint.md
    <feature-em-andamento>/
      plan.md             ← criado pelo /start-feature
      research.md         ← opcional
  M3/
    sprint.md
```

---

## Estado = git + sprint.md (zero arquivo de estado)

| Pergunta | Como descobrir |
|----------|---------------|
| O que foi entregue? | `gh pr list --state merged --search "feature/"` |
| O que está em andamento? | `git branch -a \| grep feature/` |
| O que está planejado? | Checkboxes `- [ ]` nos `sprint.md` + linhas com status `pending` |
| Qual milestone atual? | Primeiro milestone com features `pending` ou `in_progress` |
| Próxima feature? | Primeiro item `pending` no sprint.md do milestone atual |

---

## Caminho para drift

Se em qualquer momento você não souber onde está, rode `/project-compass`.
Essa skill lê git e sprint.md e sintetiza o estado atual — sem precisar lembrar de nada.

**Frases que indicam que você precisa do `/project-compass`:**
- "onde estamos no projeto?"
- "o que falta para este milestone?"
- "qual a próxima feature?"
- "estou perdido, o que devo fazer?"
- "estou driftando"

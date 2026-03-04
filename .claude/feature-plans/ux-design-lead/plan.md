# Plan: ux-design-lead

## Problema

Claude começa cada sessão sem contexto de design acumulado. Features são adicionadas
ad-hoc, fluxos não conversam entre si, padrões derivam. O dev não consegue organizar e
transmitir intenção de UX de forma que sobreviva entre sessões.

Solução: sistema de invariantes de UX — três arquivos de spec (identity + patterns + screens)
que Claude lê antes de qualquer trabalho de design, mais uma skill `/design-review` que
formaliza o papel de head of design com procedimento mecânico de revisão.

## Arquivos a modificar

### Novos (criar)
- `.claude/ux-identity.md` — modelo mental do app (400-600 palavras, muda raramente)
- `.claude/ux-patterns.md` — tabela de decisões de interação (cresce por feature)
- `.claude/ux-screens.md` — contratos por tela: intenção, não implementação
- `.claude/commands/design-review.md` — skill head of design

### Existentes (atualizar)
- `CLAUDE.md` — adicionar spec files na tabela de hot files + seção de uso no workflow

## Passos de execução

### Passo 1 — Criar `.claude/ux-identity.md`

Conteúdo: declaração do modelo mental de Claude Terminal como constraints operacionais.

Estrutura:
```
# UX Identity: Claude Terminal

## O que é (model mental)
## Para quem e em que contexto
## Hierarquia de atenção
## Princípios como constraints (não aspirações)
## O que este app NÃO é
```

Conteúdo baseado em: CLAUDE.md (visão geral) + análise first-principles da sessão de pesquisa.

### Passo 2 — Criar `.claude/ux-patterns.md`

Conteúdo: tabela de decisões de interação derivada dos padrões existentes no código.

Formato por padrão:
```markdown
## Pattern: <Nome>
When: <condição>
Then: <padrão de interação>
Because: <rationale — modelo mental que justifica>
Screens: <onde se aplica>
Status: codified | proposed | open
```

Padrões iniciais a derivar dos hot files e screens existentes:
- Monitoramento vs. Decisão (badges passivos vs. HITL ativo)
- Ações destrutivas (confirmação obrigatória)
- Progressive disclosure (card → detail)
- Status de agente sempre visível
- Menu bar como indicador, não workspace principal
- Criação de sessão via sheet (não inline)
- Terminal como inspeção, não workspace padrão

### Passo 3 — Criar `.claude/ux-screens.md`

Conteúdo: contrato de intenção por tela. Para cada tela:
```
## <NomeDaTela>
Job: <uma frase — o trabalho que o usuário faz aqui>
Data: <o que é mostrado>
Entry: <de onde o usuário chega>
Exit: <para onde o usuário vai>
Open: <decisões de UX ainda não tomadas>
```

Telas a cobrir: Dashboard, AgentCard, NewAgentSheet, AgentTerminal, QuickTerminal,
QuickAgentView, TaskBacklog, HITLPanel, Onboarding, SkillRegistry.

### Passo 4 — Criar `.claude/commands/design-review.md`

Skill que ensina Claude a atuar como head of design. Estrutura:

```
Role declaration (autoridade + restrições)
Pre-flight (leitura obrigatória dos 3 spec files)
Review loop (RenderPreview → checklist de padrões → drift check)
Post-review (novos padrões propostos, relatório de drift)
Constraints (nunca pular RenderPreview, nunca adicionar à spec sem confirmação)
```

Linguagem da skill: instrui Claude a **executar um procedimento**, não a "expressar opinião".
Cada passo gera um output verificável: verdict table, drift report, proposed additions.

### Passo 5 — Atualizar `CLAUDE.md`

Duas mudanças:
1. Tabela de hot files: adicionar as 3 spec files + design-review.md
2. Daily commands: adicionar `/design-review` como referência de uso

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: CLAUDE.md (leve update)
- [ ] Novas dependências: não — usa Xcode MCP já configurado

## Rollback

Todos os arquivos são novos exceto CLAUDE.md. Para reverter:
```bash
rm .claude/ux-identity.md .claude/ux-patterns.md .claude/ux-screens.md
rm .claude/commands/design-review.md
# Reverter CLAUDE.md: git checkout CLAUDE.md
```

## Learnings aplicados

- Nenhum learning anterior do projeto tem impacto direto nesta feature (arquivos .md puros, sem Swift)
- Padrão de skill file (.md com fases numeradas) deriva dos skills existentes — manter consistência

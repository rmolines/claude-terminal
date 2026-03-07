# Plan: polish-sprint

## Problema

Não existe skill de "sessão de polish" que abra uma branch única e itere por uma checklist
de N pequenas melhorias (bugs conhecidos, UX tweaks, refactors), fazendo micro-commits por
item e abrindo um único PR ao final. As skills atuais forçam overhead de feature completa
por item, ou perdem rastreabilidade via commit único gigante.

## Assunções

- [assumed][background] O formato de skill existente em `.claude/commands/*.md` é suficiente para a nova skill
- [assumed][background] PR sem squash (merge commit) preserva os micro-commits individuais no histórico do main
- [assumed][background] `workflow.md` deve ser atualizado para incluir `/polish` na tabela de skills

## Deliverables

### Deliverable 1 — Skill `/polish`

**O que faz:** Cria `.claude/commands/polish.md` com o workflow completo de sessão de polish
**Critério de done:** Arquivo criado, skill navegável e coerente com os padrões existentes
**Valida:** formato de skill, workflow de branch única + micro-commits + PR único

## Arquivos a modificar

- `.claude/commands/polish.md` — CRIAR — skill completa de sessão de polish
- `.claude/rules/workflow.md` — EDITAR — adicionar `/polish` na tabela de skills

## Passos de execução

1. Criar `.claude/commands/polish.md` com skill completa
2. Editar `.claude/rules/workflow.md` — adicionar `/polish` à tabela e ao fluxo visual

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências: não

## Rollback

```bash
rm .claude/commands/polish.md
git checkout .claude/rules/workflow.md
```

## Learnings aplicados

- Skills do projeto em `.claude/commands/*.md` — formato em português, instrucional, sem `$ARGUMENTS` template quando não há args variáveis
- `/ship-feature` usa `mergeMethod: "merge"` não squash para preservar commits — confirmar no plan que o `/polish` deve especificar isso

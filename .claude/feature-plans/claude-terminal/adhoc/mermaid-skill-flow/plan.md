# Plan: mermaid-skill-flow

## Problema

O `workflow.md` tem um diagrama ASCII que descreve o fluxo de skills, mas não é renderizado visualmente pelo GitHub. Não existe representação navegável do fluxo que mostre estados, transições e loops de forma imediata.

## Solução

Adicionar um diagrama `stateDiagram-v2` Mermaid ao `workflow.md` logo após o bloco ASCII existente. O GitHub renderiza Mermaid nativamente — zero setup, version-controlled. Aplicar o mesmo diagrama no `workflow.md` do kickstart.

## Passos de execução

1. Editar `.claude/feature-plans/claude-terminal/workflow.md` — adicionar seção `## Diagrama de fluxo` com o stateDiagram-v2 após o bloco ASCII
2. Editar `~/git/claude-kickstart/.claude/rules/workflow.md` — adicionar a mesma seção
3. Commit no worktree `feature/mermaid-skill-flow`

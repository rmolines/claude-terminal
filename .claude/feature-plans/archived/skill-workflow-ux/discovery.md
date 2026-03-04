# Discovery: skill-workflow-ux
_Gerado em: 2026-03-02_

## Problema real

O sistema de skills atual tem custo de processo desconectado do tamanho da mudança.
Features pequenas pagam o mesmo overhead que features grandes. O dev esquece que `--fast`
existe porque é flag escondida no CLI. O `plan-roadmap` + `start-milestone` virou ritual
pesado para projetos em que o backlog já é conhecido. Não há caminho claro para pitches
que ainda não são features (ideias sem commitment), nem para debug investigativo sem
modificar código.

## Usuário / contexto

Dev solo usando Claude Code como squad de agentes. Quer invocar skills via UI (Claude
Terminal) além do CLI. Usa worktrees por feature. Gerencia 4+ agentes em paralelo.

## Alternativas consideradas

| Opção | Por que não basta |
|---|---|
| Manter sistema atual | Overhead desproporcional para features pequenas; discoverabilidade ruim |
| Só documentar melhor o --fast | Não resolve a UI, não resolve o backlog para múltiplos projetos |
| Adoptar Linear/GitHub Projects | Fricção de autenticação, fora do fluxo do Claude Code |

## Por que agora

M3 completo. Momento de cooldown / melhoria de tooling antes do próximo ciclo.
O próximo milestone provavelmente vai ter UI de backlog — o schema precisa existir antes.

## Escopo da feature

### Dentro

- Redesign das fases do `start-feature`: `--fast` vira padrão, `--deep` e `--discover` são opt-in
- `--discover` = Fase 0 (discovery) + Fase A (research) apenas — pitch pronto para "bet"
- Detecção de fase via arquivos existentes: tem `research.md` → começa na Fase B
- `backlog.json` como fonte da verdade (substitui `roadmap.md` + `sprint.md` como fonte)
- Seção `pitches` no `backlog.json` para ideias sem commitment ("vaso")
- Skills leem/atualizam `backlog.json` ao iniciar e fechar features
- `/close-feature` mais inteligente: checa se PR foi merged, atualiza backlog.json
- `/debug` como nova skill: só investiga (BuildProject, GetBuildLog, MCP), não commita
- Usar `/create-skill` para criar `/debug` (não criar na mão)
- `sprint.md` e `roadmap.md` ficam como documentos gerados / legíveis, não fonte

### Fora (explícito)

- UI do Claude Terminal para backlog/pitches (feature separada — `backlog-ui`)
- Meta features (features que melhoram o workflow do próprio Claude Code) — para depois
- Suporte multi-projeto no mesmo `backlog.json` — v2
- Integração com GitHub Issues / Linear

## Critério de sucesso

- `/start-feature slug` (sem flag) executa a feature sem research/plan, direto na Fase C
- `/start-feature --discover slug` gera pitch (discovery.md + research.md) e para
- `/start-feature slug` após um `--discover` anterior detecta `research.md` e começa no plan
- `backlog.json` é atualizado automaticamente ao fechar uma feature
- `/debug` investiga um erro com MCP e entrega relatório sem commitar nada
- Dev não precisa lembrar de flags para o caso de uso mais comum

## Riscos identificados

- `backlog.json` schema precisa ser estável desde o início (UI vai depender dele)
- Skills globais (`~/.claude/commands/`) e de projeto (`.claude/commands/`) são arquivos
  diferentes — mudanças no `start-feature` precisam ser sincronizadas via `/sync-skills`
- Inverter o default do `start-feature` é breaking change de UX — documentar bem

## Paradigma de referência

**Shape Up (37signals):**
- Appetite (não estimate) — quanto tempo estou disposto a gastar?
- Pitch (não spec) — problema + esboço da solução, sem detalhes prematuros
- Bet (não backlog priorizado) — você escolhe o que fazer, não uma fila
- Scope hammer — se ultrapassar o appetite, corta escopo, não estende prazo
- Cool-down — período não planejado após ciclo de features

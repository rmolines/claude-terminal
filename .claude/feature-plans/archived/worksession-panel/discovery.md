# Discovery: worksession-panel
_Gerado em: 2026-03-06_

## Problema real

O dev não consegue usar Claude Terminal como substituto do iTerm para gerenciar múltiplos
agentes Claude Code paralelos. A interface atual exige varrer N abas separadas (Skills,
Worktrees, Kanban) para reconstruir mentalmente o estado de cada "feature em desenvolvimento"
— um join mental que o app deveria fazer automaticamente.

Uma tentativa anterior ("All Sessions" na sidebar) falhou por três razões simultâneas:
cards densos sem hierarquia visual escaneável, nenhuma ação óbvia disponível a partir da
view, e desconexão entre "ver sessões" e "interagir com o terminal".

## Usuário / contexto

Dev solo usando Claude Code como força multiplicadora. Cenário típico: 3-6 agentes rodando
em paralelo em worktrees separadas, cada um numa fase diferente de uma feature
(`/start-feature`, implementando, aguardando HITL, concluído). Hoje o dev mantém uma janela
iTerm por agente porque o Claude Terminal não oferece overview que substitua essa visibilidade.

## Alternativas consideradas

| Opção | Por que não basta |
|---|---|
| "All Sessions" anterior (sidebar) | Cards densos, sem hierarquia, sem ação óbvia, desconectado do terminal — tentativa real que falhou |
| Adicionar colunas ao WorktreesView | Mantém git como entidade primária; agente vira atributo secundário — premissa errada |
| Kanban board estilo Vibe Kanban | Pesado para N<8 agentes; sem HITL approval nativo; não-nativo macOS |
| Dashboard estilo Superset | Mostra tudo — cria alarm fatigue; sem HITL inline; não-nativo macOS |

## Por que agora

O app já tem toda a infra necessária: hooks → SessionManager → HITL panel. O que falta é
a view que une worktree + agente + task numa entidade coerente com ordering por urgência.
Sem isso, o usuário continua no iTerm e o Claude Terminal não cumpre sua proposta de valor
central.

## Escopo da feature

### Dentro

- `WorkSession` como struct derivada em runtime (não `@Model` SwiftData) — agrega `AgentSession` + `WorktreeInfo` + `KanbanFeature` por projeto selecionado
- `WorkSessionService: @MainActor @Observable` singleton — faz join das 3 fontes, consolida os pollers git existentes, expõe `[WorkSession]` sorted por urgência
- Ordering automático: `HITL_PENDING > ERROR > RUNNING > DONE > IDLE`
- HITL approval inline no overview (sem navegar para outro painel)
- Nova superfície de navegação substituindo ou fundindo "All Sessions" anterior — posicionamento exato (sidebar, aba principal, tela raiz por projeto) a definir na Fase A
- Coordenação com `HITLFloatingPanelController` existente para evitar double-fire de aprovação

### Fora (explícito)

- Histórico persistido de sessões passadas — WorkSession é efêmero, some ao fechar
- Multi-repo simultâneo numa única view — escopo é sessões do projeto selecionado
- Substituição do PTY/terminal em si — o SwiftTerm continua como está
- Detalhes de git (diff, commitsAhead) como informação primária — ficam colapsados ou em tier secundário

## Critério de sucesso

> "Quando o WorkSession panel estiver pronto, eu consigo migrar meu fluxo de claudes
> paralelos do iTerm pro Claude Terminal sem precisar manter janelas de terminal externas."

Comportamentos observáveis que confirmam o critério:
- Abrir Claude Terminal e ver de imediato qual agente precisa de atenção (HITL, erro)
- Aprovar um HITL sem sair da view de overview
- Saber a fase atual de cada agente (skill rodando, idle, concluído) sem navegar para outra aba
- Selecionar um agente e abrir o terminal dele diretamente da view

## Riscos identificados

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| Join instável entre `session.cwd` e `worktree.path` | Alta | Alto | Reusar lógica `hasSession` de `WorktreesView` — prefix match já testado |
| 3 pollers git em paralelo (WorktreesView + SkillsNavigatorView + WorkSessionService) | Alta | Médio | `WorkSessionService` assume o polling; views existentes consomem o serviço |
| HITL double-fire (panel flutuante + inline simultâneos) | Média | Alto | `approveHITL` já é idempotente; suprimir panel quando `NSApp.isActive` |
| Identidade instável de `WorkSession` rows (UUID regenerado a cada poll) | Alta | Médio | `id = worktree.path` (string estável); fallback `session.sessionID` se sem worktree |
| SwiftData VersionedSchema se WorkSession for persistido | Média | Crítico | Não persistir — WorkSession é struct efêmera por design |

# Roadmap — Claude Terminal
_Gerado em: 2026-02-28_

## Visão

Um dev solo consegue gerenciar 4+ agentes Claude Code em paralelo sem perder contexto e sem
ficar preso ao computador. Ele aprova pedidos HITL em segundos com uma tecla, sabe o que cada
agente está fazendo (tokens, custo, fase) de relance no menu bar, e nunca perde uma ideia de
feature. O terminal existe, mas fica escondido — o dev vive no Mission Control.

## "Aha moment" — entrega mais rápida de valor

**Feature:** HITL approval inline — badge numérico no menu bar → clique → NSPanel flutuante
com contexto do agente → Approve com uma tecla, sem sair do foco.

**Por quê:** É a dor mais documentada no ecossistema (posts sobre "mobile approval with ntfy",
issue #242 do claude-squad pedindo desktop app, issue #209 pedindo notificações, ferramentas
DIY de 60 linhas em bash que viralizaram). Nenhum produto nativo macOS resolveu. É também a
feature que melhor demonstra o posicionamento — não é um terminal, não é um viewer, é um
centro de comando que responde ao agente para que o dev não precise fazê-lo.

**Critério de done:** O criador passa 5 dias úteis aprovando/rejeitando HITLs direto do NSPanel
sem nenhuma vez abrir um terminal para isso.

## Milestones

### M1 — Agente vivo ✅ COMPLETO (objetivo: usar o app para gerenciar 1 agente real por 5 dias úteis)

- [x] Hook pipeline end-to-end funcional — PR #3
- [x] Dashboard com status real: tokens + custo estimado + fase atual do agente — PR #4 + PR #5
- [x] HITL: badge numérico no NSStatusItem + notificação com Approve/Reject — PR #3

**Critério de done:** 5 dias úteis consecutivos gerenciando agentes reais sem abrir o terminal
para verificar status ou aprovar HITL.

### M2 — Mission Control (objetivo: substituir as abas de terminal empilhadas no workflow diário)

- [ ] Backlog de tasks funcional (SwiftData) — impacto alto, esforço baixo — diferenciador vs. claude-squad; scaffold já existe
- [ ] Terminal embedded (SwiftTerm) por agente — impacto médio, esforço médio — prioridade alta no M2; isolamento de queue por instância obrigatório
- [ ] Múltiplos agentes simultâneos com worktree isolation — impacto alto, esforço alto — base para o workflow paralelo real
- [ ] Criação de nova task via app (dispara `start-feature`/`fix` via Claude Code) — impacto médio, esforço médio — fluxo completo de orquestração

**Critério de done:** O criador não abre Warp/iTerm para gerenciar a squad — só para sessões
fora do app.

### M3 — DMG público (objetivo: 10 usuários externos instalaram e usaram sem ajuda)

- [ ] Setup automático de hooks via app em `~/.claude/settings.json` (zero config manual) — impacto alto, esforço médio — bloqueador de UX para novos usuários
- [ ] DMG notarizado + Sparkle auto-update — impacto alto, esforço alto — instalar no M3, não deixar para véspera; stapling + EdDSA keys
- [ ] README com GIF de demo do HITL flow (o momento mais impressionante para o demo) — impacto alto, esforço baixo
- [ ] PR no `awesome-claude-code` (hesreallyhim/awesome-claude-code) + Show HN — impacto alto, esforço baixo — 100 stars atingíveis no dia do Show HN

**Critério de done:** 10 instalações em Macs que não são os seus, sem você ajudar a instalar.
Pelo menos 2 delas reportaram um bug espontaneamente.

## Impact/effort matrix

| Feature | Impacto | Esforço | Milestone | Justificativa |
|---|---|---|---|---|
| Hook pipeline end-to-end | Alto | Baixo | M1 | Critical path; scaffold existe, é ligar os fios |
| Dashboard status real (tokens, custo, fase) | Alto | Baixo | M1 | Dor #1 documentada; resolve "N terminais empilhados" |
| HITL: badge + NSPanel flutuante | Alto | Médio | M1 | Aha moment mais documentado; DIY bash scripts provam demanda |
| Backlog de tasks (SwiftData) | Alto | Baixo | M2 | Diferenciador vs. claude-squad; scaffold existe |
| Terminal embedded (SwiftTerm) | Médio | Médio | M2 | Prioridade alta no M2; gotcha de queue por instância já documentado |
| Múltiplos agentes simultâneos | Alto | Alto | M2 | Worktree isolation; SwiftTerm multi-instance tem edge cases |
| Criação de task via app | Médio | Médio | M2 | Fluxo completo de orquestração; manual no M1 é aceitável |
| Setup automático de hooks | Alto | Médio | M3 | Zero config para novos usuários; diferenciador de UX |
| DMG notarizado + Sparkle | Alto | Alto | M3 | Integrar no M3, não na véspera do Show HN |
| PR awesome-claude-code + Show HN | Alto | Baixo | M3 | 100 stars atingíveis no dia; timing terça-quinta 8-10h EST |

## Fora de escopo (v1)

- **Multi-model support** (Aider, Codex, etc.) — 90% dos usuários de claude-squad usam exclusivamente Claude Code; generalidade não converte em adoção
- **Colaboração em equipe / cloud sync** — Warp Drive tentou e foi ignorado pelos heavy users; produto é pessoal primeiro
- **Agent builder customizado** — feature de crescimento, não de ativação
- **SSH / VPS / secrets management** — produto diferente, 6+ meses de trabalho adicional
- **Windows / Linux** — PTY + SwiftData + notarização = macOS-only por design
- **GitHub Issues / Linear / Jira integration** — fricção de autenticação, distrai do aha moment

## Próximo passo

```
/start-milestone M2
```

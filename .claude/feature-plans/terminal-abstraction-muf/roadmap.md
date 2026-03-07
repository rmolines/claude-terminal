# Roadmap — Claude Terminal: Terminal Abstraction (MUF)

_Gerado em: 2026-03-06_

## Visao

Um dev consegue completar uma feature inteira — do /start-feature ao PR merged — sem tocar
diretamente no terminal. O dev digita, clica, aprova e direciona, mas tudo isso acontece numa
camada UI acima do Claude Code. O PTY existe e pode ficar visivel como janela de inspecao,
mas nunca e a superficie de interacao primaria.

**O terminal e read-only por padrao. O app e o teclado.**

O frame correto e incident.io, nao Grafana: Claude Terminal e um sistema de decisao que usa
monitoramento como contexto. Cada milestone elimina uma classe de acoes que o dev ainda faz
diretamente no terminal. O criterio nao e "feature entregue" — e "dev completou X sem tocar
no PTY".

## "Aha moment"

**Feature:** Completar uma feature inteira sem tocar no terminal.

**O que isso significa na pratica:** Dev abre o app, seleciona o projeto, lanca /start-feature
via UI, acompanha o progresso no dashboard, aprova/responde/direciona o agente via paineis do
app, e ve o PR aberto — tudo sem digitar uma linha no PTY. O terminal pode estar visivel como
viewer, mas o dev nunca clicou nele.

**Por que e o aha moment certo:** O loop atual e quebrado em dois lugares: (1) o HITL atual
cobre so PermissionRequest — todas as outras interacoes mid-run ainda vao para o terminal;
(2) a sessao precisa ser iniciada no terminal. Resolver so um deles nao entrega o aha — o dev
ainda precisa "sair" do app em algum momento. O momento de ruptura e quando ele percebe que
nao saiu em nenhum ponto do ciclo.

**Criterio de done:** Dev completa uma feature do inicio ao PR sem tocar no PTY em nenhum momento.

## MUF por milestone

| Milestone | Acao que o dev para de fazer no PTY |
|---|---|
| M4 | Interagir com o agente durante a sessao (aprovar, responder perguntas, direcionar, confirmar plano) |
| M5 | Cancelar agente preso, ajustar permissoes, monitorar custo |
| M6 | Iniciar nova sessao Claude Code com a skill e o worktree corretos |
| M7 | Consultar o historico do que o agente fez |

**Loop completo sem PTY = M4 + M6 entregues.** M5 e M7 fecham os casos extremos e enriquecem.

---

## Milestones

### M4 — HITL Redesign: todas as interacoes happy path (objetivo: zero abertura de terminal durante uma sessao ativa)

O HITL atual cobre apenas PermissionRequest hooks. A maioria das interacoes que o dev ainda
faz no terminal durante uma sessao Claude Code nao tem representacao no app: responder perguntas
do agente, enviar mensagem de steering mid-run, confirmar ou rejeitar uma proposta de mudanca.
Este milestone redesenha o HITL para cobrir o conjunto completo de interacoes happy path.

**Interacoes a cobrir:**

- [ ] Tool permission approval (redesign do atual) — contexto rico: qual tool, qual comando exato,
  qual arquivo seria afetado — impacto: alto | esforco: medio
- [ ] Resposta a perguntas do agente (quando Claude Code solicita input e aguarda) — impacto: alto | esforco: medio
- [ ] Steering mid-run (enviar mensagem ao agente enquanto ele trabalha, sem interromper o PTY) — impacto: alto | esforco: alto
- [ ] Confirmacao de proposta de mudanca (quando Claude apresenta um plano e espera go/no-go) — impacto: alto | esforco: medio
- [ ] Rejected tool — retry com instrucao (rejeitar e enviar contexto sobre por que, sem abrir terminal) — impacto: medio | esforco: medio

**Criterio de done:** Dev passa 5 dias uteis sem abrir terminal para interagir com agente ativo.
Todas as interacoes happy path do Claude Code tem representacao no app.

---

### M5 — Controle total sobre agentes rodando (objetivo: zero abertura de terminal para gerenciar agentes ativos)

- [ ] Cancel agent from UI (SIGTERM ao processo PTY) — impacto: alto | esforco: baixo
- [ ] Stuck-agent detection (sem output por threshold configuravel → alerta visual + notificacao) — impacto: alto | esforco: medio
- [ ] Configurable cost cap (auto-stop quando budget do dev excede threshold; configuravel por sessao) — impacto: alto | esforco: medio
- [ ] Permission management UI (editar allowlist de ferramentas sem abrir ~/.claude/settings.json) — impacto: medio | esforco: medio

**Criterio de done:** Dev passa 5 dias uteis sem abrir terminal para matar ou inspecionar agente
rodando. Cancel funciona. Stuck-alert dispara pelo menos uma vez em uso real. Cost cap para um
agente antes que o dev precise intervir manualmente.

---

### M6 — Workflow initiation: lancar sessao sem terminal (objetivo: zero abertura de terminal para iniciar trabalho)

- [ ] Workflow initiation panel (selecionar repo → selecionar skill → preencher contexto → lancar
  claude com worktree correto) — impacto: alto | esforco: alto
- [ ] Multi-project support (gerenciar sessoes em multiplos repos, nao so o CWD atual) — impacto: alto | esforco: medio
- [ ] Session resume — A: reabrir PTY com processo ainda rodando; B: nova sessao com contexto da
  anterior copiado — impacto: medio | esforco: medio

**Criterio de done:** Dev inicia 3+ sessoes em uma semana sem abrir terminal. Workflow initiation
funciona para pelo menos /start-feature e /fix com worktree isolation correto.

---

### M7 — Session memory + lancamento publico (objetivo: zero abertura de terminal para entender sessoes passadas)

- [ ] Session history viewer (timeline de acoes por sessao, com base no delivery event log) — impacto: alto | esforco: medio
- [ ] "What happened" summary por sessao (resumo estruturado do que o agente fez, arquivos modificados,
  outcome) — impacto: alto | esforco: alto
- [ ] Diff viewer por sessao (quais arquivos mudaram, antes/depois) — impacto: medio | esforco: medio
- [ ] PR no awesome-claude-code + Show HN — impacto: alto | esforco: baixo

**Criterio de done:** Dev responde "o que o agente fez ontem nesse repo?" sem abrir terminal.
10 usuarios externos ativos apos Show HN.

---

## Impact/effort matrix

| Feature | Impacto | Esforco | Milestone | Justificativa |
|---|---|---|---|---|
| Tool permission approval (redesign) | Alto | Medio | M4 | Base do HITL atual — precisa de contexto rico (comando exato, arquivo afetado) |
| Resposta a perguntas do agente | Alto | Medio | M4 | Interacao mais frequente que PermissionRequest — agente pergunta antes de agir |
| Steering mid-run | Alto | Alto | M4 | GitHub Mission Control identificou como diferenciador #1 do seu MVP |
| Confirmacao de proposta de mudanca | Alto | Medio | M4 | Happy path Q1: Claude apresenta plano, dev confirma — sem isso o dev abre terminal |
| Rejected tool + retry com instrucao | Medio | Medio | M4 | Fecha o loop de rejeicao — sem isso reject e um beco sem saida |
| Cancel agent from UI | Alto | Baixo | M5 | Panic path Q3 mais solicitado; sem ele o dev ainda precisa do terminal em crise |
| Stuck-agent detection | Alto | Medio | M5 | Q1 incompleto — agente preso silenciosamente nao tem sinal no app hoje |
| Configurable cost cap | Alto | Medio | M5 | Top pedido pos-adocao — "vi $10 sumirem em 30s" (AI Engineering Report, Faros AI) |
| Permission management UI | Medio | Medio | M5 | Setup path Q3 — editar JSON a mao bloqueia devs menos tecnicos |
| Workflow initiation panel | Alto | Alto | M6 | Fecha o loop: app passa de "approval tool" para "interface completa" |
| Multi-project support | Alto | Medio | M6 | Sem isso o app so vale para quem tem um projeto ativo — limita adocao |
| Session resume (A + B) | Medio | Medio | M6 | Fire-and-forget precisa de retomada de contexto para funcionar como daily driver |
| Session history viewer | Alto | Medio | M7 | Amp Chronicle: feature mais solicitada pos-adocao segundo changelogs publicos |
| "What happened" summary | Alto | Alto | M7 | Diferenciador vs. git log — linguagem natural, nao raw diff |
| Diff viewer por sessao | Medio | Medio | M7 | Complementa history viewer; baseline para rollback futuro |
| Show HN + awesome-claude-code | Alto | Baixo | M7 | Desbloqueado — sem dependencia de GIF |

---

## Fora de escopo

- **Multi-model / outros CLIs** — foco exclusivo em Claude Code e suas convencoes (hooks, skills, worktrees)
- **Colaboracao em equipe / cloud sync** — produto pessoal por design; Warp Drive tentou, heavy users ignoraram
- **SSH / VPS management** — produto diferente; devs com Claude Code estao no local
- **Rollback / checkpoint automatico** — alto esforco, Q3 de baixissima frequencia; git resolve 90% dos casos
- **Audit logs / distributed tracing** — enterprise/compliance, nao daily dev UX
- **Skill builder / custom agent creator** — Q4 heavy; feature de crescimento, nao de ativacao
- **Windows / Linux** — PTY + SwiftData + notarizacao = macOS-only por design

---

## Template MUF para sprint.md (adicionar em /start-milestone)

```text
## MUF deste milestone

- **Acao que o dev para de fazer no terminal:** [descricao exata]
- **Criterio de verificacao:** [5 dias uteis sem abrir terminal para fazer X]
- **Features minimas para atingir o MUF:** [lista]
- **Features enabler** (infra que outra feature precisa): [lista]
- **Features enhancement** (valor incremental, nao bloqueia MUF): [lista separada]
```

---

## Proximo passo

```text
/start-milestone M4 terminal-abstraction-muf
```

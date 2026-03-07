# Explore: Registro de Entregas e Base para Kanban

## Pergunta reframeada

Como instrumentar os workflows de skill para capturar artefatos de entrega
persistentemente — garantindo que nenhuma entrega se perca — e qual estrutura de dados
serve tanto o tracking CLI atual quanto consumo futuro por uma aba kanban em SwiftUI?

## Premissas e o que não pode ser

- **Premissa 1:** Atualmente entregas se perdem — skills atualizam `backlog.json` mas
  sobrescrevem state, dados históricos ficam para sempre em `null` (13 de 17 features
  têm `startedAt: null` no arquivo real)
- **Premissa 2:** O `backlog.json` é ao mesmo tempo fonte de verdade e artefato mutável
  editado por `jq` — não há proteção contra writes concorrentes de agentes paralelos
- **Premissa 3:** SQLite é a solução óbvia quando se pensa em "mais estruturado" — mas
  isso é mapeamento automático, não análise do contexto
- **Constraint:** Skills rodam em sessões Claude Code efêmeras; o único canal confiável
  de persistência é escrita em arquivo — não há transações, não há rollback nativo
- **Constraint:** Não pode exigir input humano durante skill run; não pode quebrar skills
  existentes sem migration path; deve ser git-diffable (binários quebram auditoria via PR)
- **O que não pode ser a solução:** migrar `backlog.json` para SQLite — SQLite não é
  git-diffable, exigiria dependência adicional no app Swift (GRDB/SQLite.swift), e as
  skills passariam a usar queries SQL inline em bash — mais frágil, sem vantagem real
  para o tamanho do dataset (< 50KB com 100+ features)

## Mapa do espaço

**Build systems (Bazel, Jenkins, SLSA):** entrega = evento imutável com fingerprint +
contexto (quem construiu, quando, em qual workflow, com qual commit). Jenkins persiste
cada build num diretório estruturado; Bazel usa Content-Addressed Store (CAS). Nenhuma
ferramenta reescreve o artefato anterior — append always.

**Sistemas de ticketing (Linear, GitHub Projects v2, Taskwarrior):** estado = enum de
sistema fixo (`pending|in-progress|done|cancelled`) com transições auditadas. Linear
separa `state.type` (invariante de sistema, usado pelo código) de `state.name` (display
label, customizável). Taskwarrior preserva campos desconhecidos sem modificação —
extensível sem quebrar versões antigas. GitHub Projects v2 usa campos dinâmicos, poderoso
para GUI mas complexo para scripts/skills.

**Event sourcing local-first (LiveStore, hledger, SQLite WAL):** todos convergem para
dois níveis: (1) event log append-only como fonte de verdade imutável; (2) projeção
materializada para leitura. hledger nunca altera o journal — relatórios são computados
sobre ele. SQLite WAL é fundamentalmente append-only. LiveStore usa esse triângulo:
event log + projeção SQLite + sync inspirado em git.

**`backlog.json` atual (leitura real):** estrutura flat com `milestones`, `features`,
`pitches`, `icebox`. Cada feature tem `id`, `title`, `status`, `milestone`, `path`,
`dependencies`, `branch`, `prNumber`, `startedAt`, `completedAt`, `createdAt`. Funciona
bem para leitura humana e em markdown. Problemas reais: 13/17 features com
`startedAt: null`; sem `mergedAt`; sem `sortOrder`; `icebox` é array separado em vez de
`status` value; `updatedAt` no root é string fixa não atualizada pelas skills.

## O gap

- **Dados históricos irrecuperáveis:** `backlog.json` sobrescrito por `jq` perde o que
  estava antes. Não há registro de quando cada transição aconteceu. Sem event trail, um
  kanban mostra apenas "estado atual" — sem histograma de cycle time, sem burn-down.

- **Zero auditoria de skill runs:** nenhuma feature registra qual skill/sessão fez o
  `close-feature`. Se o agente falhar no meio e re-rodar, `completedAt` é sobrescrito
  silenciosamente com o novo timestamp — dado errado, sem aviso.

- **Writes concorrentes sem proteção:** dois agentes paralelos fazendo
  `jq ... > tmp && mv` no mesmo `backlog.json` — o último `mv` ganha, escrita do
  primeiro é descartada. O schema atual não tem defesa contra isso.

- **Schema não é kanban-ready:** falta `sortOrder` (preservar ordem dentro da coluna),
  `labels` (categorização visual), `updatedAt` por item (detectar mudanças para sync).
  `pitches` e `icebox` como arrays separados duplicam lógica no consumer SwiftUI.

## Hipótese

A solução correta não é migrar para SQLite nem reescrever as skills — é introduzir
**`events.jsonl`** (NDJSON, uma linha por evento, append-only) como fonte de verdade
imutável ao lado do `backlog.json` existente, que se torna projeção materializada.

Skills fazem `echo '{"ts":"...","skill":"close-feature","featureId":"...","event":"closed","pr":55}' >> events.jsonl`
(append atômico, safe para agentes paralelos) e depois atualizam `backlog.json` como
hoje. O app Swift consome `backlog.json` para o kanban rápido. Quando a aba de gestão
de projetos existir, ela pode materializar views ricas diretamente de `events.jsonl`.

Junto com isso, três ajustes de schema em `backlog.json`: (1) adicionar `mergedAt`
distinto de `completedAt`; (2) adicionar `sortOrder: Int` por feature; (3) unificar
`pitches` + `icebox` em `features` com `status: "awaiting-bet"` e `status: "icebox"`.

**Como chegamos aqui:**
- Descartado SQLite: não git-diffable, dependência extra no app, queries SQL inline em
  bash — complexidade sem vantagem para < 50KB de dados
- Descartado "reescrever backlog.json para ser event-sourced": quebraria todas as skills
  existentes e o consumer no app de uma vez
- Tensão resolvida: `events.jsonl` é append-only (safe para concorrência) sem exigir
  mudança no formato de leitura do `backlog.json` — os dois coexistem

**Stress-test:** Dois arquivos = dois pontos de falha. Se uma skill escreve o evento em
`events.jsonl` mas falha antes de atualizar `backlog.json`, os dois ficam
dessincronizados. O consumidor SwiftUI que lê `backlog.json` estará desatualizado até a
próxima reconciliação. Isso é aceitável apenas se existir um mecanismo de
reconciliação — um script ou a própria app que recalcula `backlog.json` a partir de
`events.jsonl` quando detecta inconsistência. Sem esse mecanismo, `events.jsonl` vira
log morto e `backlog.json` continua sendo a única fonte de verdade.

## Próxima ação

**Veredicto:** melhoria em projeto existente — afeta skills, schema de dados, e o modelo
de dados futuro para a aba kanban no app Swift

**Próxima skill:** `/start-feature --discover`
**Nome sugerido:** `delivery-event-log`

**O que ficou consolidado:**
- JSON > SQLite para este projeto: git-diffable, zero dependências novas, scripts jq
  que já existem, tamanho de dataset que nunca vai escalar além de KB
- Event log append-only (`events.jsonl`) é o padrão correto para auditabilidade e
  concorrência — `backlog.json` como projeção materializada, não fonte primária
- Schema mínimo para kanban: `sortOrder`, `labels`, `mergedAt`, `updatedAt` por item,
  e unificação de `pitches`/`icebox` em `features` com novos valores de `status`

---

Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `delivery-event-log`.
O contexto está preservado em `.claude/feature-plans/delivery-event-log/explore.md`.

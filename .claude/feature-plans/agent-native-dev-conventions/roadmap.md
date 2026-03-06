# Roadmap — agent-native-dev-conventions
_Gerado em: 2026-03-05_

## Visão

Um dev usando Claude Code abre qualquer projeto — novo ou legado — e o agente já chega com o
mapa certo: hot files, atores centrais, invariantes arquiteturais, convenções específicas do
projeto. Não por magia nem por grep extensivo, mas porque o projeto foi estruturado segundo
convenções projetadas para cognição de agente, e uma ferramenta as extrai automaticamente
para o contexto inicial.

O framework transforma "CLAUDE.md como README denso" em "índice de convenções machine-readable"
— a camada que falta entre o que AGENTS.md permite e o que agentes de fato precisam para
performar bem desde o início da sessão.

## "Aha moment" — entrega mais rápida de valor

**Feature:** Manifesto público com URL canônica — o "12factor.net para AI coding com Claude Code"

**Por quê:** A pesquisa confirma o gap: há handbooks informais (Tweag), papers acadêmicos
(arxiv 2602.20478), e arquivos por-projeto (AGENTS.md, CLAUDE.md) — mas não existe um documento
numerado, prescritivo, com URL canônica que qualquer dev possa linkar e dizer "nosso projeto
segue as agent-native conventions". Conventional Commits funcionou exatamente assim: spec-first
com URL canônica, tooling derivado em cima. O `awesome-cursorrules` (38k stars) mostrou que
adoção explode quando há ponto de referência linkável, não quando há ferramenta.

**Critério de done:** Documento publicado com URL permanente (GitHub Pages ou domínio próprio),
com 6-10 princípios numerados, exemplos concretos em Swift e TypeScript, e anti-padrões
explícitos. Dev lê e reconhece: "isso nomeia exatamente a fricção que eu sinto."

## Milestones

### M1 — Manifesto v0.1 (objetivo: documento público linkável, aberto a feedback)

- [ ] Articular 6-10 princípios numerados com exemplos concretos e anti-padrões — impacto alto, esforço médio
- [ ] Publicar em repo separado (`agent-native-dev-conventions`) com GitHub Pages — impacto alto, esforço baixo
- [ ] README focado no problema (não na solução): "por que AGENTS.md não basta?" — impacto médio, esforço baixo
- [ ] Versionar como v0.1-beta e abrir para issues/discussão — modelar Conventional Commits — impacto médio, esforço baixo
- [ ] Anunciar em r/ClaudeAI e HN "Ask HN: feedback on agent-native dev conventions" — impacto médio, esforço baixo

**Critério de done:** Manifesto publicado com URL canônica + pelo menos 5 issues/comentários
externos com feedback substancial (positivo ou crítico) + nenhum princípio central contestado
sem resposta documentada.

### M2 — CLI + Dogfooding no Claude Terminal (objetivo: convenções validadas empiricamente)

- [ ] CLI `agent-index` (repo separado, integrável): `agent-index generate` extrai índice de convenções do projeto (hot files, atores centrais, invariantes arquiteturais de rules/, CLAUDE.md) — impacto alto, esforço médio
- [ ] Output: `.agent-index.md` ou seção enriquecida de CLAUDE.md — não árvore de arquivos (agents já descobrem isso) — impacto alto, esforço baixo
- [ ] Integração com Claude Terminal: `SessionStart` hook que auto-gera o índice e injeta no contexto — impacto alto, esforço médio
- [ ] Validação empírica no Claude Terminal: comparar sessões com/sem índice em tarefas reais — impacto alto, esforço baixo
- [ ] Iterar manifesto com base no dogfooding: ≥1 princípio revisado a partir de uso real — impacto alto, esforço baixo
- [ ] Suporte a Swift/SPM + TypeScript/Next.js como primeiros dois tipos de projeto — impacto médio, esforço médio
- [ ] Guia de adoção: "como aplicar ao seu projeto em 20 minutos" — impacto médio, esforço baixo

**Critério de done:** CLI roda em claude-terminal + ao menos 1 métrica de melhoria documentada
(proxy aceitável: número de iterações do agente para encontrar o arquivo certo, antes/depois)
+ manifesto atualizado para v0.2 com mudanças motivadas por dogfooding.

### M3 — Evangelização (objetivo: tração pública mensurável)

- [ ] Artigo definitivo: "The Missing Layer Between AGENTS.md and Agent Performance" — com dados do M2 — impacto alto, esforço médio
- [ ] Show HN + cross-post nos espaços relevantes (r/ClaudeAI, r/cursor, Hacker News) — impacto alto, esforço baixo
- [ ] Referenciar papers relevantes (arxiv 2602.20478, ETH Zurich study, arxiv 2509.14744) — impacto médio, esforço baixo
- [ ] Guia de contribuição: como adicionar suporte a um novo tipo de projeto na CLI — impacto médio, esforço baixo
- [ ] Colher 3 projetos externos adotando voluntariamente e documentar como estudos de caso — impacto alto, esforço médio

**Critério de done:** Artigo publicado + ≥100 GitHub stars no repo do manifesto + ≥1 projeto
externo documentado usando as convenções com resultado medido.

## Impact/effort matrix

| Feature | Impacto | Esforço | Milestone | Justificativa |
|---|---|---|---|---|
| Manifesto com URL canônica | Alto | Médio | M1 | Ponto de referência linkável é o que gerou adoção do .cursorrules; sem URL canônica não há Conventional Commits |
| Publicação v0.1-beta + issues abertos | Alto | Baixo | M1 | Conventional Commits fez isso — iterar publicamente é mais rápido que escrever spec perfeita sozinho |
| README focado no problema | Médio | Baixo | M1 | Adoção começa quando dev reconhece o problema, não quando lê a solução |
| CLI `agent-index generate` | Alto | Médio | M2 | Dogfooding valida o manifesto; ETH Zurich: spec sem uso real gera spec errada |
| Integração SessionStart hook | Alto | Médio | M2 | Plugin pattern natural no Claude Code; baixo atrito de adoção |
| Suporte Swift/SPM + TS/Next.js | Médio | Médio | M2 | Um tipo de projeto = nicho; dois = padrão |
| Validação empírica Claude Terminal | Alto | Baixo | M2 | Prova a premissa com dado real antes de qualquer claim público |
| Artigo definitivo com dados | Alto | Médio | M3 | Prettier e Conventional Commits tiveram um post fundador que virou referência permanente |
| Show HN launch | Alto | Baixo | M3 | Canal natural para o público-alvo |
| MCP server de navegação on-demand | Médio | Alto | Fora de escopo | Adjacente ao core, resolve descoberta on-demand não estruturação de contexto inicial |
| Lint rules executáveis para invariantes | Alto | Alto | Fora de escopo | O gap mais importante do espaço mas Semantic Web trap — custo de manutenção alto; roadmap pós-v1 |
| Decaimento de confiança em docs | Médio | Alto | Fora de escopo | Insight original, mas requer infra separada; scope creep clássico para M1 |
| Suporte a agentes além do Claude Code | Baixo | Médio | Fora de escopo | Generalizar cedo dilui foco; pesquisa mostra que regras específicas por ferramenta performam melhor |

## Fora de escopo (v1)

- **MCP server de navegação on-demand** — complementar ao core, mas resolve problema diferente (discovery on-demand vs. contexto inicial estruturado); distrai do aha moment
- **Lint rules executáveis para invariantes arquiteturais** — o gap mais importante do espaço a longo prazo, mas custo de manutenção alto cria o mesmo risco da Semantic Web; roadmap pós-v1
- **Decaimento de confiança em documentação** — insight genuinamente original (explore.md), mas feature separada com infra própria; entrará como princípio no manifesto, não como ferramenta no M1
- **Suporte a agentes além do Claude Code** — generalizar antes de ter validação dilui foco e piora qualidade das convenções; pesquisa confirma que regras tool-specific performam melhor que genéricas

## Repo e estrutura esperada

```text
agent-native-dev-conventions/   # repo separado
├── README.md                   # problema, não solução
├── spec/
│   └── v0.1.md                 # manifesto — princípios numerados
├── examples/
│   ├── swift-spm/              # exemplos concretos em Swift
│   └── typescript-nextjs/      # exemplos em TypeScript
├── cli/                        # agent-index CLI (M2)
│   └── ...
└── CHANGELOG.md
```

Integrável com Claude Terminal no M2 via:

```bash
# SessionStart hook em claude-terminal
agent-index generate --format claude-md >> CLAUDE.md
```

Ou como MCP resource (alternativa a avaliar no M2).

## Próximo passo

```text
/start-milestone M1 agent-native-dev-conventions
```

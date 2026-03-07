# Discovery: docs-lifecycle
_Gerado em: 2026-03-06_

## Problema real

O workflow de desenvolvimento acumula conhecimento em artefatos append-only sem papel claro
(LEARNINGS.md, MEMORY.md, HANDOVER.md, CLAUDE.md armadilhas). Nenhum foi definido com intenção
sobre quem lê, quando, e com que custo. O resultado é conhecimento duplicado em 4 lugares, retrieval
O(N) em todos eles, e o failure mode mais perigoso: "confident irrelevance" — agente cita docs
corretos sobre um sistema que já não existe dessa forma.

O problema não é falta de metadata — é excesso de artefatos sem papel definido.

## Usuário / contexto

Dev solo usando Claude Code com sessões frequentes. A cada nova feature, o agente carrega MEMORY.md
e LEARNINGS.md inteiros sem capacidade de distinguir "isso se aplica agora" de "isso foi relevante
em março de 2025". Após ~20 features, o corpus vira asserções não-verificáveis citadas com confiança.

## Alternativas consideradas

| Opção | Por que não basta |
|---|---|
| Adicionar metadata a LEARNINGS.md + MEMORY.md | Tipa artefatos redundantes em vez de consolidar — o problema de excesso de artefatos persiste |
| Reorganizar LEARNINGS.md manualmente | Sem papel claro definido, a reorganização não tem critério de curadoria |
| Criar KNOWLEDGE.md separado | Adiciona um 5° artefato sem eliminar os redundantes |
| Temporal knowledge graph (Zep) | Requer infraestrutura externa — overkill para workflow file-based |
| Greenfield only (sem migração) | Corpus híbrido e duplicado persiste indefinidamente |

## Por que agora

LEARNINGS.md já tem 739 linhas. MEMORY.md tem ~200 linhas. Ambos sobrepõem CLAUDE.md armadilhas.
A partir deste ponto, cada feature adiciona ruído em 3 lugares simultaneamente. Consolidar agora
custa menos do que consolidar com 1500 linhas — e elimina o problema estruturalmente.

## Arquitetura de artefatos proposta

| Artefato | Papel | Quem lê | Limite | Quem escreve |
|---|---|---|---|---|
| **CLAUDE.md armadilhas** | Pitfalls de alta confiança, sempre-relevantes | Agente — sempre, automático | Cresce com barra alta de entrada | close-feature (curado) |
| **MEMORY.md** (+ topic files) | Conhecimento ativo — decisões, padrões, gotchas médios. Índice com links para topic files | Agente — sempre, automático | 200 linhas (cap real) | close-feature + agente |
| **memory/\*.md** | Detalhe por domínio (swift-concurrency.md, swiftdata.md, etc.) | Agente — sob demanda, via link | Sem limite | Overflow do MEMORY.md |
| **HANDOVER.md** | Narrativa humana de sessão | Humano | Sem limite | close-feature |
| **CHANGELOG.md** | Histórico de releases | Humano | Sem limite | close-feature |
| **LEARNINGS.md** | **Eliminar** — papel absorvido pelos anteriores | — | — | — |

Separação de concerns: artefatos de agente (CLAUDE.md + MEMORY.md + topic files) vs. artefatos
humanos (HANDOVER.md + CHANGELOG.md). Os dois grupos nunca se confundem.

## Escopo da feature

### Dentro

- **Eliminar LEARNINGS.md**: migrar entradas com valor para MEMORY.md (seções tipadas) ou topic
  files; entradas já cobertas pelo CLAUDE.md armadilhas: descartar (sem duplicar)
- **Reestruturar MEMORY.md**: de append log para seções tipadas (`## Decisions`, `## Patterns`,
  `## Gotchas`) com overflow para `memory/*.md` topic files quando uma seção cresce demais
- **Redefinir close-feature**: ao fechar uma feature, classificar o conhecimento gerado em
  (a) pitfall de alta confiança → CLAUDE.md armadilhas, (b) decisão/padrão → MEMORY.md,
  (c) narrativa → HANDOVER.md. Nada vai mais para LEARNINGS.md.
- **Redefinir start-feature Passo B.4**: ler MEMORY.md estruturado + topic files relevantes
  (por seção, não dump completo); LEARNINGS.md removido do loop

### Fora (explícito)

- Decay signal / `[needs-review]` — o cap de 200 linhas do MEMORY.md é o mecanismo de forcing
  function; decay explícito fica para próxima feature se necessário
- `/review-learnings` skill autônoma — fora do escopo
- Auto-review via GitHub Action ou cron — fora do escopo
- Mudanças no HANDOVER.md além do que já existe — fora do escopo
- Mudanças no CHANGELOG.md — fora do escopo
- Metadata tipada (TYPE/TAGS/CONFIDENCE/LAST) em cada entrada — simplificado: seções por tipo
  já resolvem o problema de filtro sem overhead de metadata por linha

## Critério de sucesso

- LEARNINGS.md não existe mais — conteúdo migrado ou descartado
- MEMORY.md tem seções tipadas (`## Decisions`, `## Patterns`, `## Gotchas`) com no máximo
  200 linhas; overflow em `memory/*.md` topic files com links
- close-feature não escreve mais para LEARNINGS.md — classifica o conhecimento em CLAUDE.md
  ou MEMORY.md com papel claro
- start-feature Passo B.4 lê seções relevantes do MEMORY.md (não dump completo)
- Zero duplicação entre CLAUDE.md armadilhas e MEMORY.md

## Riscos identificados

- **Perda de conteúdo na migração**: LEARNINGS.md tem 739 linhas — migração one-shot com backup
  obrigatório. Algumas entradas vão ser descartadas deliberadamente (duplicatas do CLAUDE.md);
  critério de descarte precisa ser explícito no plan.md.
- **MEMORY.md estoura o cap durante migração**: ao consolidar, MEMORY.md vai receber conteúdo
  novo. Estratégia: criar topic files imediatamente para domínios com 5+ entradas (swift-concurrency,
  swiftdata, build-system, etc.) e manter MEMORY.md como índice.
- **close-feature com decisão de roteamento**: pedir ao agente para classificar "vai para CLAUDE.md
  ou MEMORY.md?" adiciona um passo de julgamento. Mitigação: critério claro no texto da skill
  (alta confiança + sempre-relevante = CLAUDE.md; tudo mais = MEMORY.md).
- **Complexidade pode escalar**: se durante planejamento o escopo crescer, usar `/plan-roadmap`
  para quebrar em milestones.

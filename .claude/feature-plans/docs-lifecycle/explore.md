# Explore: Ciclo de vida do conhecimento gerado pelo workflow

## Pergunta reframeada

Como um sistema de workflow de desenvolvimento deve gerenciar os artefatos de conhecimento que ele mesmo gera — garantindo que sejam consumidos por sessões futuras, podados quando obsoletos, e não acumulem como peso morto em vez de base de conhecimento?

## Premissas e o que não pode ser

- **Premissa implícita 1:** Quanto mais documentação gerada pelo close-feature, melhor — na verdade, volume sem estrutura destrói sinal.
- **Premissa implícita 2:** O agente vai "saber" procurar a documentação passada relevante — na prática, o agente carrega o que está disponível no contexto; sem pré-filtragem, é O(N).
- **Premissa implícita 3:** Documentação é válida até ser explicitamente marcada como errada — ao contrário do que a aviação e medicina praticam (padrão inverso: inválido até re-confirmado).
- **Constraint — o que não pode ser a solução:** "Ler tudo em cada feature start" — escala linearmente, devora context window. Curadoria manual periódica — sem sinal de quais docs estão obsoletos, review vira checkbox. "Nunca deletar" — acumulação monotônica garantida.

## Mapa do espaço

**Knowledge Management (Evergreen Notes / Zettelkasten)**
- Notas nunca estão "prontas" — cada revisita é reescrita, não anotação
- Notas órfãs (sem links) surfaceiam naturalmente como sinal de obsolescência
- PARA method usa bucket Archive para separar "não-ativo" do "atual" — mas é manual

**Dev Workflow Documentation**
- ADRs (Architecture Decision Records): status explícito (`proposed`, `accepted`, `deprecated`, `superseded`) + cadeia de supersede — o padrão mais replicado para lifecycle de decisões
- `adr-tools` / `log4brains`: tooling que cria o link old→new no momento da criação, não como edição posterior
- Living Documentation (Cyrille Martraire): doc co-localizada com artefato + verificada por testes → falha de teste = alarme de obsolescência. Decay estruturalmente impossível quando coupling é enforced pelo build.

**Campos adjacentes — mecanismo crítico**
- Aviação (FAA Part 121, SKYbrary): toda página de manual tem data de revisão; emendas urgentes têm data de vigência nomeada; re-emissão completa é mandatória em intervalos prescritos
- Medicina (NICE guidelines): vigilância mandatória a cada 3 anos; guideline não-vigilada é tratada como potencialmente insegura, não estável. Retiradas ficam listadas como "do not use", não deletadas.
- Militar (Army TG 176): todo SOP tem data de revisão obrigatória na capa; SOPs obsoletos vão para binder de arquivo, não deletados

## O gap

- close-feature gera documentação event-coupled no write (bom), mas **sem metadata de lifecycle** — nenhum tipo, condição de aplicabilidade, confiança, próxima revisão
- MEMORY.md e LEARNINGS.md são **append logs cronológicos** — estruturalmente incompatíveis com retrieval por um agente em session start
- **Não existe "mandatory decay by default"** — documentos são assumidos válidos até marcação explícita; campos de alta confiabilidade fazem o oposto
- start-feature **não lê artefatos do close-feature sistematicamente** — o conhecimento acumulado não entra no loop de execução de features seguintes
- **Authorship attribution collapse** (Agente D): após ~20 features, nenhuma entrada tem dono de decisão rastreável, nível de confiança ou condição de falsificabilidade. O corpus parece conhecimento, é na verdade asserções não-verificáveis.

## Hipótese

O problema não é quantidade de documentação, é ausência de **tipagem e metadata de lifecycle** nas entradas. A unidade de conhecimento precisa mudar de "documento por feature" para "entrada atômica tipada com condições de aplicabilidade". Cada entrada deveria ter: tipo (gotcha/padrão/decisão), condição (quando se aplica), confiança (alta/média/baixa), última-reconfirmação (slug da feature), e status (ativo/superseded/arquivado). O mecanismo de reconfirmação — inspirado na aviação — inverte o padrão: documentos são inválidos após N features sem uso ou re-confirmação, não válidos por default.

**Como chegamos aqui:**
- Descartamos "melhor organização de LEARNINGS.md" — reorganizar um append log não resolve o problema de retrieval O(N) nem o decay silencioso
- Descartamos "review manual periódico" — sem sinal automático de quais entradas estão obsoletas, review vira checkbox (confirmado pela pesquisa de ADRs e medicina)
- A tensão resolvida: entre curadoria humana (insustentável) e automação total (perde contexto) — solução é estrutura nos dados que torna o decay visível sem exigir disciplina

**Stress-test:** A hipótese assume que tipar entradas no momento do close-feature é cognitivamente viável — que o agente ou humano terá contexto suficiente para classificar "gotcha vs padrão vs decisão" e definir condições de aplicabilidade. Se o overhead de estruturação for alto o suficiente para ser evitado, o sistema regride para o append log atual. O risco real é que a estrutura vire burocracia de baixo valor que ninguém preenche corretamente.

## Próxima ação

**Veredicto:** Melhoria em existente — modificação nas skills close-feature, start-feature e MEMORY.md

**Próxima skill:** `/start-feature --discover`
**Nome sugerido:** `docs-lifecycle`

**O que ficou consolidado:**
- Append log cronológico (MEMORY.md como está) é incompatível com retrieval eficiente por agente — precisa de tipagem por tipo de entrada
- O campo mais defensivo na literatura é "mandatory decay by default" — entradas precisam de re-confirmação ativa, não silêncio como proxy de validade
- O failure mode mais perigoso é "confident irrelevance" — agente cita docs com confiança sobre um sistema que já não existe dessa forma; invisível até auditoria humana

---
Faça `/clear` para limpar a sessão e então rode `/start-feature --discover docs-lifecycle`.
O contexto está preservado em `.claude/feature-plans/docs-lifecycle/explore.md`.
---

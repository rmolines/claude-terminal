# Explore: Convenções de Dev Projetadas para Humanos

## Pergunta reframeada

As convenções centrais da engenharia de software — estrutura de arquivos, controle de versão, documentação — foram projetadas para cognição humana (memória espacial, trabalho assíncrono, transferência de contexto entre pessoas). À medida que agentes de IA realizam o trabalho real de desenvolvimento, essas convenções criam fricção. O que mudaria se redesenhadas do zero para um mundo onde o ator primário é um agente?

---

## Premissas e o que não pode ser

- **Premissa implícita 1:** As convenções precisam ser substituídas. Na verdade, a maioria pode ser mantida — o que falta é uma camada adicional de especificação executável por cima, não um substituto.
- **Premissa implícita 2:** O problema é de *formato* (markdown vs JSON). O problema real é de *função* — documentação serve a dois fins distintos (especificação + rationale) que nunca foram separados.
- **Premissa implícita 3:** Agentes precisam de menos contexto. Inversamente, precisam de *contexto diferente* — não narrativo, mas declarativo.
- **Constraint: não pode quebrar compatibilidade com devs humanos.** Times são híbridos por enquanto; qualquer solução que só funciona para agentes é inviável.
- **Constraint: a Semantic Web tentou exatamente isso e fracassou.** Infraestrutura de conhecimento legível por máquina morre quando o custo de manutenção excede o valor para humanos. A solução deve ser byproduct de práticas que humanos adotariam de qualquer forma.

---

## Mapa do espaço

**Estrutura de arquivos:**

- Hierarquia Unix (1969) = prótese de memória espacial para humanos. O `/usr` existe por um acidente de dois discos físicos — e ainda está em todo Linux hoje. A separação `src/main/test` (Maven 2004) mapeia como devs *pensam* sobre o trabalho, não como compiladores ou agentes o acessam.
- Agentes navegam por busca (grep, glob, embedding search), não por browsing. Hierarquia profunda adiciona indireção sem benefício para agentes.
- AGENTS.md / CLAUDE.md (2024-2025) = primeira tentativa sistemática de um segundo índice do projeto otimizado para janela de contexto de LLM, não para navegação humana. 60k+ repos adotaram AGENTS.md (Linux Foundation / Agentic AI Foundation).
- Problema atual: AGENTS.md escritos como READMEs densos têm Flesch Reading Ease ~16.6 (range de documentos legais) e são ignorados ou mal seguidos por agentes. Arquivos curtos, curados, com informação genuinamente não-óbvia: -28% runtime, -16% tokens (arxiv 2601.20404).
- O que funciona agora: graph-structured navigation via MCP (CodeCompass) — expor o grafo AST de dependências como ferramenta queryável alcança 99.4% de cobertura arquitetural vs 76.2% para retrieval vanilla (arxiv 2602.20048).

**Controle de versão:**

- Git foi projetado para confiança distribuída entre humanos, não para coordenação de agentes. Todas as convenções sobre ele (commit messages, PRs, GitFlow) são workarounds para colaboração humana assíncrona.
- Conventional Commits (2019) = primeira convenção git explicitamente projetada para ser parseada por máquinas (changelog generators, semantic-release). Inflection point — commit history deixou de ser só narrativa e virou fonte de dados.
- AgentGit (arxiv 2511.00628): propõe versionamento de *estado do agente* (não só código), com commit, revert e branching de trajetórias de execução. Resultado: menos redundância, menos tokens, suporte a exploração paralela.
- Atomic (empresa, early 2026): VCS construído do zero para volume de commits em velocidade de máquina. Armazena AI provenance nos registros de mudança. Pré-produto mas o thesis é sólido.
- Git worktrees = resposta pragmática atual para paralelismo multi-agente. Particionamento espacial de arquivos substitui coordenação matemática.

**Documentação:**

- Man pages (1971) → otimizadas para teletipo e impressão. Javadoc (1995) → co-localização para evitar rot. README GitHub (2008) → leitor chegando frio via browser, precisa de contexto em 60s. AGENTS.md (2024) → primeiro formato com IA como leitor primário.
- Literate Programming (Knuth 1984) tentou inverter a relação: documentação como artefato primário, código como byproduct. Perdeu para Javadoc. O mercado revelou: devs preferem comentar código do que escrever ensaios com trechos de código.
- "Codified Context" (arxiv 2602.20478): arquitetura de 3 camadas validada empiricamente em 283 sessões / 108K linhas de C#: (1) constituição hot-memory sempre carregada ~660 linhas, (2) 19 agentes especialistas por domínio, (3) 34 documentos cold-memory acessados por busca de keyword via MCP. Mapeia exatamente para o que este projeto construiu intuitivamente (CLAUDE.md + rules/ + ux-screens.md).

---

## O gap

**1. Camada de especificação executável não existe.**
Toda regra arquitetural hoje vive em linguagem natural (CLAUDE.md, skills, rules/). Um agente as lê e *interpreta* a cada sessão. Não há primitive para "esta invariante deve ser verificada contra qualquer changeset proposto". O gap entre "documento de regra" e "lint rule para arquitetura" ainda não foi fechado em nenhuma ferramenta mainstream.

**2. Primitivos de coordenação operam na escala temporal errada.**
Branches git existem para trabalho de dias/semanas (escala humana). Agentes completam tasks em segundos a minutos. O primitive correto é uma *transação com escopo de task* — isolamento efêmero com predicate de validação atômica — mais próximo de MVCC de banco de dados do que de git branch. Não existe em nenhuma ferramenta.

**3. Conflito semântico é invisível.**
Git detecta conflitos de texto (duas edições na mesma linha). Não detecta conflitos semânticos (dois agentes modificando arquivos diferentes que compartilham uma interface). O equivalente seria um *intent lock* — antes de modificar um escopo semântico (uma interface, um schema, um protocolo compartilhado), o agente registra intenção. Outros agentes veem o lock. Não existe hoje.

**4. Documentação não tem mecanismo de decaimento de confiança.**
Sistemas de formiga funcionam porque feromônios evaporam. Trilhas antigas somem. Uma colônia com feromônios permanentes fica presa roteando por obstáculos que não existem mais. O análogo no código: CLAUDE.md com informação desatualizada que agentes seguem com convicção total. Nenhum formato de documentação hoje codifica staleness. Git tem os timestamps mas requer síntese humana.

---

## Hipótese

**O verdadeiro gap não é estrutura de arquivos melhor nem git mais rápido — é a ausência de uma camada de especificação executável.**

Toda convenção que hoje existe em linguagem natural (CLAUDE.md, skills, rules/) tem implícita uma *invariante arquitetural* que agentes precisam verificar mas não conseguem checar programaticamente. A reforma "agent-first" não é sobre substituir convenções humanas: é sobre extrair suas invariantes implícitas e torná-las machine-checkable.

Documentação serve dois fins que nunca foram separados: **especificação** (o que deve ser verdade — pode ser tornado executável) e **rationale** (por que esta escolha em vez de outra — pode permanecer linguagem natural, mas só precisa ser lido uma vez para construir policy). Um sistema agent-optimal separaria esses dois sharply. A camada spec seria um sistema de constraints verificável contra qualquer changeset proposto.

**Como chegamos aqui:**

- Descartado: "reformar estrutura de arquivos" — graph navigation via MCP (CodeCompass) resolve o problema de descoberta sem restruturar projetos existentes; reorganizar files é fricção desnecessária.
- Descartado: "substituir git" — o modelo de dados do git (DAG content-addressed) é sólido; o problema está na camada semântica em cima (commit messages como narrativa, PR como transferência de contexto social). Ferramentas novas como Atomic são interessantes mas prematuras para apostar.
- Tensão resolvida: "documentação estruturada vs linguagem natural" → ambas são necessárias, servem funções distintas. A resposta não é JSON — é separar spec (executável) de rationale (narrativo, lido uma vez).

**Stress-test:** A Semantic Web tentou exatamente criar infraestrutura de conhecimento legível por máquina (RDF, OWL) e morreu porque o custo de manutenção excedeu o valor para humanos — ninguém escrevia as ontologias. O mesmo risco existe aqui: especificações executáveis de invariantes arquiteturais são caras de escrever e manter. Se não forem byproduct de práticas que humanos adotariam de qualquer forma, ninguém vai mantê-las e a camada vai apodrecer mais rápido que CLAUDE.md já apodrece. A aposta só funciona se as ferramentas reduzem o custo de manutenção a quase zero (geração automática de specs a partir de code, não escrita manual).

---

## Próxima ação

**Veredicto:** novo produto / novo projeto — o espaço de problema descrito é grande demais para uma feature do Claude Terminal. Mas há um caso de uso imediato: o próprio Claude Terminal como laboratório onde experimentar essas convenções.

**Próxima skill:** `/start-feature --discover`
**Nome sugerido:** `agent-native-dev-conventions`

**O que ficou consolidado:**

- **Graph navigation > file restructuring.** Expor o grafo de dependências como MCP tool (CodeCompass pattern) resolve descoberta sem quebrar compatibilidade. Não reorganize arquivos — indexe-os.
- **Especificação executável é o gap central.** Cada linha do CLAUDE.md que diz "nunca faça X" deveria ter uma lint rule associada. A infra para isso não existe; construir seria o projeto real.
- **Decaimento de confiança em docs é non-obvious e não resolvido.** Nenhuma ferramenta ou formato hoje codifica staleness de forma que agentes possam usar. O insight da formiga é genuinamente novo — documentação agent-native precisa de mecanismo de evaporação.

---

Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `agent-native-dev-conventions`.
O contexto está preservado em `.claude/feature-plans/agent-native-dev-conventions/explore.md`.

# Discovery: agent-native-dev-conventions
_Gerado em: 2026-03-05_

## Problema real

Convenções de engenharia de software foram projetadas para cognição humana — memória espacial,
navegação por hierarquia de pastas, leitura linear de documentação. Quando um agente de IA abre
um projeto Swift com 40 arquivos ou um Next.js com 30 páginas e múltiplas seções, ele não tem
um mapa eficiente de "o que é o quê, o que afeta o quê". O agente navega às cegas: faz grep,
lê arquivos irrelevantes, perde contexto, comete erros que um dev humano familiarizado com o
projeto não cometeria.

O problema não é que agentes são ruins em navegar — é que projetos não foram estruturados
para serem navegáveis por agentes. Nenhuma convenção mainstream de engenharia endereça isso.

## Usuário / contexto

Dev solo ou time pequeno usando Claude Code (ou agentes equivalentes) como força multiplicadora.
Sente a fricção quando o agente precisa de muitas iterações para encontrar o arquivo certo, quando
propõe mudanças sem entender o impacto em outras partes do projeto, ou quando ignora convenções
documentadas no CLAUDE.md porque não as "encontrou" no contexto da tarefa.

Contexto específico: projetos com estrutura não-trivial — Swift com múltiplos targets/actors,
Next.js com páginas/abas/seções, monorepos. Projetos simples (10 arquivos) não sofrem tanto.

## Alternativas consideradas

| Opção | Por que não basta |
|---|---|
| CLAUDE.md bem escrito | Escrito por humanos para humanos — denso, narrativo, sem mapa de estrutura real do projeto. Não escala com a complexidade do projeto. |
| Reestruturar hierarquia de pastas | Fricção alta, quebra compatibilidade com tooling existente. O problema é de indexação, não de layout físico. |
| RAG / embedding search | Resolve busca semântica mas não resolve descoberta estrutural ("o que este arquivo importa?", "quem depende deste módulo?"). Infra pesada para projetos pequenos. |
| CodeCompass / grafo AST via MCP | Resolve navegação on-demand mas pressupõe que o agente sabe o que perguntar. O problema começa antes: o agente não tem contexto suficiente para fazer as perguntas certas. |

## Por que agora

- AGENTS.md / CLAUDE.md (2024-2025) = primeiro formato com IA como leitor primário, mas ainda
  escrito como README denso. 60k+ repos adotaram — o padrão existe mas não está otimizado.
- "Codified Context" (arxiv 2602.20478): arquitetura de 3 camadas validada empiricamente —
  constituição hot-memory + agentes especialistas + cold-memory por busca. O que falta é a
  camada de geração automática dessa constituição a partir da estrutura real do projeto.
- Momento: a infra (MCP, hooks, worktrees) chegou à maturidade em 2025. As convenções não
  acompanharam. Há um gap entre o que a infra permite e o que os projetos expõem para os agentes.

## Escopo

### Dentro
- Framework de convenções: princípios articulados para estruturar projetos de forma agent-navigable
- Ferramenta concreta (demonstração): gerador de índice de projeto que produz um mapa
  estrutural carregado no contexto inicial do agente (CLAUDE.md enriquecido automaticamente)
- Claude Terminal como laboratório: primeiro projeto onde aplicar e validar as convenções
- Publicação: artigo / manifesto para evangelização do paradigma

### Fora (explícito)
- Substituir git, estrutura de pastas, ou qualquer convenção humana existente
- MCP server de navegação on-demand (adjacente, não o core)
- Decaimento de documentação (importante, mas feature secundária)
- Especificação executável / lint rules (importante, mas feature secundária)
- Suporte a agentes que não são Claude Code (por enquanto)

## Critério de sucesso

- Framework articulado em documento público (manifesto / artigo) com princípios concretos
  e aplicáveis — não apenas observações
- Ferramenta que gera um índice de projeto e reduz o número de iterações que um agente
  precisa para encontrar o arquivo certo (validado empiricamente no Claude Terminal)
- Adoção: pelo menos um projeto externo aplicando as convenções voluntariamente

## Riscos identificados

- **Semantic Web trap**: infraestrutura de conhecimento legível por máquina morre quando
  o custo de manutenção excede o valor para humanos. O índice gerado deve ser byproduct
  automático de práticas que devs adotariam de qualquer forma — nunca escrita manual.
- **Scope creep**: os 3 gaps do explore (executável, grafo, decaimento) são todos reais
  e relacionados. O risco é tentar resolver os três ao mesmo tempo e não terminar nenhum.
  O bet primário é navegação/descoberta; os outros dois são roadmap.
- **Validação difícil**: medir "menos iterações" requer controle. Proxy aceitável:
  comparar sessões de Claude Code no mesmo projeto com/sem o índice gerado.

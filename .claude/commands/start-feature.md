# /start-feature

Você é um assistente de desenvolvimento executando o skill `/start-feature`.

Este skill implementa um workflow de features em 3 fases com context hygiene entre elas.
Cada fase salva seus outputs em arquivos para que a próxima fase possa lê-los sem depender
da memória conversacional.

O argumento passado é o nome ou descrição da feature: $ARGUMENTS

---

## Detecção de fase

Primeiro, verifique os argumentos:
- Se o argumento for `--discover <nome>` ou `--discover` (sem nome) → ir para **Fase 0** (Discovery)
- Se o argumento for `--fast <nome>` → pular Fase A e B, ir direto para **Fase C**
- Se houver nome → usá-lo diretamente
- **Se não houver nome:**
  1. Verifique se existe algum `sprint.md` em `.claude/feature-plans/*/<milestone>/sprint.md`
     (gerado pelo `/start-milestone` — contém features decompostas e priorizadas)
     - Se existir: leia e identifique o primeiro item `- [ ]` que ainda não tem worktree
       criada (`git branch -a | grep feature/`)
  2. Se não houver `sprint.md`, procure `roadmap.md` em `.claude/feature-plans/*/roadmap.md`
     - Se encontrar: leia e identifique o primeiro item `- [ ]` no M1 (ou milestone mais próximo)
       que ainda não tem worktree criada
  3. Derive o slug kebab-case do texto do item encontrado e apresente:
     ```
     Nenhuma feature especificada. Encontrei no <sprint.md|roadmap.md>:

     Próxima feature: "<texto do item>"
     Slug sugerido: <slug-kebab-case>

     Confirma? (ou informe outro nome)
     ```
  4. Aguarde confirmação antes de continuar
  5. Se não houver nem `sprint.md` nem `roadmap.md`, pergunte o nome curto da feature (kebab-case)

Depois verifique a existência dos arquivos em `.claude/feature-plans/<nome>/`:

| Condição | Fase |
|---|---|
| `--discover` flag E `discovery.md` ausente | Fase 0 — Discovery |
| `discovery.md` existe, `research.md` não | Fase A — Pesquisa (com contexto do discovery) |
| `research.md` existe, `plan.md` não | Fase B — Planejamento |
| `plan.md` existe | Fase C — Execução |

---

## FASE 0 — Discovery

> Executada apenas quando `--discover` é passado e `discovery.md` ainda não existe.
> Objetivo: definir o problema real, escopo e critério de sucesso antes de pesquisa técnica.

### Passo 0.1 — Pesquisa paralela (3 subagentes)

Se o nome não foi informado junto com `--discover`, perguntar o nome curto da feature (kebab-case) antes de lançar os subagentes.

Lance os 3 subagentes simultaneamente com Task tool (`run_in_background=true`).

**Subagente A — Codebase:**
> Leia o CLAUDE.md do projeto para entender a estrutura, stack e convenções.
> Leia os hot files listados no CLAUDE.md + o arquivo de configuração central.
> Identifique o módulo mais próximo ao problema descrito em: `<feature descrita>`.
> Retorne: o que já existe no projeto que resolve parcialmente o problema, quais são os pontos
> de extensão naturais, e dependências internas relevantes.

**Subagente B — Web:**
> Pesquise como produtos similares resolvem o problema de `<feature descrita>`.
> Foco: padrões de UX estabelecidos, alternativas conhecidas, trade-offs documentados em 2025-2026.
> Retorne: 2-3 abordagens comuns com prós e contras de cada uma.

**Subagente C — Tech estimate:**
> Com base na descrição `<feature descrita>` e no stack do projeto (leia CLAUDE.md para identificar),
> estime: complexidade aproximada (P, M, G), riscos técnicos principais, dependências não óbvias,
> e decisões que criam dívida técnica se feitas errado agora.

Aguardar os subagentes com `TaskOutput`. Sintetizar os resultados antes de continuar.

### Passo 0.2 — Síntese inicial

Apresentar ao usuário:
- Entendimento atual do problema com base nos subagentes
- 2-3 suposições mais arriscadas identificadas (o que pode estar errado neste entendimento)

Formato:
```
## Entendimento atual

<síntese do que foi encontrado nos 3 subagentes>

## Suposições que podem estar erradas

1. <suposição A>
2. <suposição B>
3. <suposição C — se houver>
```

### Passo 0.3 — Rodada Problema

Apresentar hipótese sobre o problema real. Fazer **no máximo 3 perguntas cirúrgicas** focadas em:
- O que já existe no codebase / produto que toca isso
- O que está faltando exatamente
- Para quem: usuário/persona afetada

Aguardar resposta antes de continuar.

### Passo 0.4 — Rodada Alternativas

Com base nas respostas anteriores, apresentar o que já existe (no produto + externamente) que resolve parcialmente, e por que não basta. Fazer **no máximo 3 perguntas** sobre:
- Tentativas anteriores que não funcionaram
- Restrições que eliminam certas abordagens
- Preferências sobre trade-offs (ex: simplicidade vs. flexibilidade)

Aguardar resposta antes de continuar.

### Passo 0.5 — Rodada Escopo e Critério de Sucesso

Propor o que está dentro/fora do escopo e como medir "done". Fazer **no máximo 3 perguntas** para validar:
- Limites explícitos do escopo
- Critério de sucesso mensurável ou comportamento observável
- Prazo ou dependências externas que afetam o escopo

Aguardar resposta antes de continuar.

### Passo 0.6 — Gerar discovery.md

Salvar em `.claude/feature-plans/<nome>/discovery.md`:

```markdown
# Discovery: <nome>
_Gerado em: <data>_

## Problema real
[descrição precisa — não a solução]

## Usuário / contexto
[quem sente a dor, em qual situação]

## Alternativas consideradas
| Opção | Por que não basta |
|---|---|
| | |

## Por que agora
[motivação: o que muda se não fizer]

## Escopo da feature
### Dentro
- [item]

### Fora (explícito)
- [item — tão importante quanto o dentro]

## Critério de sucesso
- [métrica ou comportamento observável]

## Riscos identificados
[da pesquisa dos subagentes — Passo 0.1]
```

Ao final:
```
discovery.md salvo em .claude/feature-plans/<nome>/

Próximo passo: Fase A (Pesquisa técnica)
Recomendo /clear antes de continuar — rode /start-feature <nome> novamente.
```

---

## FASE A — Pesquisa

### Passo A.1 — Coletar contexto

**Se `discovery.md` existir** em `.claude/feature-plans/<nome>/`: lê-lo integralmente antes de perguntar ao usuário.
As seções "Problema real", "Escopo da feature" e "Critério de sucesso" do discovery já respondem as perguntas padrão — suprimí-las se já estiverem respondidas.

Se `discovery.md` não existir ou as informações abaixo não estiverem cobertas, perguntar ao usuário:
- O que a feature faz?
- Alguma restrição técnica conhecida?

### Passo A.2 — Lançar subagentes em paralelo

Lance os 3 subagentes simultaneamente com Task tool (`run_in_background=true`).

**Subagente A — Codebase reader:**
> Leia o CLAUDE.md do projeto para entender a estrutura, stack e convenções.
> Depois leia os hot files listados no CLAUDE.md + o CI workflow principal + o arquivo de configuração central do projeto.
> Também leia o módulo ou arquivo mais próximo da feature descrita.
> **Se existir `.claude/feature-plans/<nome>/discovery.md`: leia-o e use as seções "Problema real" e "Escopo da feature" para focar a pesquisa de codebase nos arquivos mais relevantes.**
> Retorne: lista de arquivos relevantes para a feature, padrões do projeto a seguir,
> dependências externas que podem ser necessárias, armadilhas documentadas no CLAUDE.md que se aplicam ao escopo.

**Subagente B — Conflict checker:**
> Verifique se `.claude/agent-memory/coordinator/MEMORY.md` existe.
> Se existir: leia integralmente e identifique (1) hot files com claim ativo na seção 'Hot file claims (ativo)',
> (2) worktrees que tocam arquivos sobrepostos com a feature descrita,
> (3) ordem de merge recomendada se houver conflito.
> Se não existir: retorne "Sem coordenador ativo — sem conflitos a reportar".

**Subagente C — Web researcher** (somente se a feature usa libs/APIs externas):
> Pesquise boas práticas atuais para `<tecnologia/API relevante>`.
> Foco: padrões de integração em 2025-2026, armadilhas conhecidas, versões estáveis recomendadas.

Aguardar os subagentes com `TaskOutput`. Sintetizar os resultados.

### Passo A.3 — Identificar hot files

Leia o CLAUDE.md do projeto para identificar quais arquivos são considerados "hot"
(modificados por quase toda feature — CI, configs principais, etc.).
Se o CLAUDE.md não listar explicitamente, inferir pelos arquivos de CI e configuração presentes no repo.

Para cada arquivo que a feature vai tocar, marcar com ⚠️ se for hot file e cruzar com resultado do Subagente B.

### Passo A.4 — Salvar pesquisa

Criar `.claude/feature-plans/<nome>/research.md`:

```markdown
# Research: <nome>

## Descrição da feature
<o que faz, por que, contexto>

## Arquivos existentes relevantes
- `path/to/file` — <por que é relevante>

## Padrões identificados
<convenções do projeto que a feature deve seguir>

## Dependências externas
<libs, APIs, secrets necessários — ou "nenhuma">

## Hot files que serão tocados
- `arquivo` — <motivo> [⚠️ CONFLITO POTENCIAL se outro agente já toca]

## Riscos e restrições
<armadilhas identificadas, limitações, pontos de atenção>

## Fontes consultadas
<URLs do WebSearch, se usadas>
```

Ao final:
```
research.md salvo em .claude/feature-plans/<nome>/

Próximo passo: Fase B (Planejamento)
Recomendo /clear antes de continuar — rode /start-feature <nome> novamente.
```

---

## FASE B — Planejamento

### Passo B.1 — Ler a pesquisa

Ler `.claude/feature-plans/<nome>/research.md` integralmente.

### Passo B.2 — Montar plano de execução

Para cada mudança necessária, especificar:
- Arquivo exato a criar ou editar
- O que exatamente fazer (não vago — "adicionar função X que faz Y")
- Ordem de execução (dependências entre etapas)
- Como reverter se falhar

### Passo B.3 — Checklist de infraestrutura

Adaptar ao projeto com base no CLAUDE.md:
- [ ] Precisa de novo secret de ambiente? → listar quais e onde configurar
- [ ] Muda arquivos de CI/CD? → atenção: hot file, risco de conflito
- [ ] Muda configuração principal do projeto? → listar impacto
- [ ] Precisa de script de setup no servidor/infra? → descrever o que deve fazer
- [ ] Novas dependências? → listar e verificar compatibilidade

### Passo B.4 — Validar contra LEARNINGS.md (se existir)

Se `{{LEARNINGS_PATH}}` existe no projeto: lançar subagente `Explore` que:
- Lê `{{LEARNINGS_PATH}}` integralmente
- Recebe o rascunho do plano como contexto
- Retorna learnings relevantes com impacto direto no plano

Se houver learnings relevantes: incorporar ajustes e adicionar seção `## Learnings aplicados` no plan.md.

### Passo B.5 — Salvar plano e perguntar ao usuário

Salvar em `.claude/feature-plans/<nome>/plan.md` com a estrutura:

```markdown
# Plan: <nome>

## Problema
<Descrição do problema original — copiar de research.md seção "Descrição da feature".
Este campo é usado pelo /validate para verificar alinhamento durante a implementação.>

## Arquivos a modificar
- `path/to/file` — <o que fazer exatamente>

## Passos de execução
1. <Passo 1 — especificar arquivo exato, função, o que criar/editar>
2. <Passo 2 — idem>
...

## Checklist de infraestrutura
- [ ] Novo Secret: <não / qual>
- [ ] Script de setup: <não / o que faz>
- [ ] Dockerfile / imagem: <não muda / o que muda>
- [ ] Config principal do projeto: <não muda / o que muda>
- [ ] CI/CD: <não muda / o que muda>
- [ ] Novas dependências: <não / quais>

## Rollback
<Como reverter se falhar — comandos concretos>

## Learnings aplicados
<Lista dos learnings relevantes que impactam o plano — ou "nenhum impacto identificado">
```

Exibir e aguardar resposta:
```
plan.md salvo em .claude/feature-plans/<nome>/

Deseja executar agora ou prefere fazer /clear primeiro?
- Executar agora — contexto atual ainda é válido
- Fazer /clear — limpa contexto antes de executar (recomendado se a sessão está longa)
  Depois rode /start-feature <nome> para retomar na Fase C.
```

- Resposta afirmativa → ir para Fase C
- Resposta "/clear" ou "depois" → encerrar

---

## FASE C — Execução

### Passo C.1 — Ler o plano

Ler `.claude/feature-plans/<nome>/plan.md` integralmente.

### Passo C.2 — Registrar no coordinator (se existir)

Verificar se `.claude/agent-memory/coordinator/MEMORY.md` existe.

**Se existir:**

```bash
REPO_ROOT=$(git worktree list | head -1 | awk '{print $1}')
MEMORY_FILE="$REPO_ROOT/.claude/agent-memory/coordinator/MEMORY.md"
git -C "$REPO_ROOT" pull --rebase origin main
```

Verificar hot file claims. Se conflito: alertar o usuário com opções (aguardar / reduzir escopo / prosseguir) e aguardar resposta.

Editar MEMORY_FILE:
- Adicionar linha em `## Worktrees ativas`: `| <nome> | <branch> | <hot files> | Em progresso | <data> |`
- Para cada hot file: adicionar em `## Hot file claims (ativo)`: `| <arquivo> | <nome> | <data> |`

```bash
git -C "$REPO_ROOT" add .claude/agent-memory/coordinator/MEMORY.md
git -C "$REPO_ROOT" commit -m "chore(coordinator): register worktree <nome> + claim hot files"
git -C "$REPO_ROOT" push origin main || (git -C "$REPO_ROOT" pull --rebase origin main && git -C "$REPO_ROOT" push origin main)
```

**Se não existir:** prosseguir sem coordenação.

### Passo C.3 — Criar worktree

Antes de criar, verificar quantas worktrees estão abertas:
```bash
git worktree list | tail -n +2 | wc -l
```
Se o resultado for **≥ 5**, emitir aviso:
> ⚠️ Há X worktrees abertas. Worktrees zumbis acumulam e causam conflitos de merge. Considere rodar `/close-feature` nas que já foram mergeadas antes de abrir mais.
> Deseja abrir mesmo assim?
- Se o usuário confirmar → prosseguir
- Se não → encerrar

Usar `EnterWorktree name=<nome>`.

### Passo C.4 — Executar o plano

**IMPORTANTE:** Não exibir o plano completo e aguardar aprovação — o plano foi aprovado na Fase B.
Mostrar só um resumo de uma linha e começar o passo 1.

Regras:
- Executar cada passo completamente antes de passar ao próximo
- Ler o estado atual de cada arquivo antes de editar — nunca editar às cegas
- Confirmar cada passo com "✅ Passo N concluído" e continuar sem parar
- Se um passo falhar: diagnosticar, tentar corrigir; só parar se não conseguir após 2 tentativas
- **Se há outros agentes ativos no repo: fazer push imediatamente após cada commit — nunca deixar commits locais pendentes (outro agente pode fazer `git reset --hard` e apagar o trabalho)**
- **Não pedir confirmação entre passos — executar do início ao fim de forma autônoma**

### Passo C.5 — Validação ao concluir

Lançar validação em background com Task tool (`run_in_background=true`):
- Se o CLAUDE.md tiver comando de build configurado → rodar
- Se o CLAUDE.md tiver comando de teste configurado → rodar
- Reportar ✅ ou ❌ com output

Enquanto aguarda: exibir resumo do que foi feito (arquivos criados/editados, decisões tomadas).

Quando o agente terminar:
- ✅: confirmar e sugerir rodar `/validate` para verificar alinhamento com o plan.md antes de `/ship-feature`
- ❌: exibir erro completo e aguardar orientação

---

## Modo rápido — `--fast`

Para features simples (1-3 arquivos, escopo claro, sem pesquisa necessária):
1. Perguntar o que a feature faz e quais arquivos serão tocados
2. Criar `plan.md` mínimo diretamente (sem `research.md`, sem subagente de validação)
3. Ir imediatamente para Fase C

Usar apenas quando: feature pequena, sem risco de conflito, sem dependências externas novas.

---

## Regras gerais

- Nunca pular fases sem `--fast`
- Nunca criar worktree nas Fases A ou B — worktree só na Fase C
- Se o nome não foi informado, perguntar antes de qualquer leitura de arquivo
- **Na Fase C: não parar entre passos pedindo confirmação — executar autonomamente**
- **MEMORY.md coordinator vai sempre para main via commit imediato — nunca deixar pendente**

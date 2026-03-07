# Explore: Skill Freshness Check via Session Hook

## Pergunta reframeada

Como garantir que as skills locais do Claude Code (`~/.claude/commands/` e `.claude/commands/`) estejam em sincronia com a fonte de verdade (repo `rmolines/claude-kickstart`) usando o `SessionStart` hook para detectar drift automaticamente antes de qualquer trabalho?

## Premissas e o que não pode ser

- **Premissa 1:** Skills divergem silenciosamente entre máquinas e ao longo do tempo — sem sinal de alerta
- **Premissa 2:** O `SessionStart` hook do Claude Code pode rodar shell commands e injetar contexto que Claude vê no startup
- **Premissa 3:** O check deve ser automático, não manual — a fricção de um `/check-skills` manual é alta o suficiente para ser ignorada
- **Premissa 4:** Existe uma fonte de verdade centralizada (`rmolines/claude-kickstart` no GitHub)
- **Constraint — não pode ser auto-update:** skills que mudam no meio de uma sessão produzem comportamento inconsistente; o risco de um commit ruim corromper todas as sessões imediatamente é alto demais
- **Constraint — não pode bloquear:** `SessionStart` é non-blocking por design; mesmo se bloqueasse, staleness não é erro, é aviso
- **Constraint — não pode usar timestamps de arquivo:** mtime muda em `git checkout`/`cp`/`rsync` sem mudança de conteúdo — comparações são nonsensical

## Mapa do espaço

**Claude Code hooks (`SessionStart`):**
- Dispara em: `startup`, `resume`, `clear`, `compact`
- Recebe JSON via stdin com `session_id`, `cwd`, `source`, `permission_mode`
- stdout é adicionado como contexto que Claude vê (não aparece ao usuário diretamente)
- Pode rodar qualquer shell command incluindo `git`, `curl`, `gh`
- Configuração: `~/.claude/settings.json` (global) ou `.claude/settings.json` (projeto)
- Pode filtrar por `source` via matcher regex (ex: só `startup`, não `resume`/`clear`)

**Skills no Claude Code (estado atual):**
- `~/.claude/commands/*.md` — global, todas as sessões
- `.claude/commands/*.md` — por projeto
- Sem versionamento embutido, sem update detection, sem diff para skill files
- O plugin system DO tem SHA pinning em `installed_plugins_v2.json` — mas skills/commands são arquivos soltos

**Como outros tools resolvem freshness:**
- **oh-my-zsh:** epoch-day gate (14 dias) + `git fetch` + comparação de commit hash — bloqueia startup brevemente
- **update-notifier (npm):** timestamp gate (24h) + child process desanexado + notifica na próxima invocação — zero latência
- **Homebrew:** timestamp de last fetch vs threshold — inplace antes de install, não no startup
- **chezmoi:** three-way state (source/target/actual) com hash store persistente — mais sofisticado, detecta drift externo

**Prompt versioning no ecossistema:**
- LangSmith/Langfuse/Braintrust: registry com SHA imutável + label mutável (`production`) — overkill para skills locais
- Git-native: skills como código, `git pull` para atualizar — o pattern mais simples e o que melhor se encaixa aqui

## O gap

- Claude Code não tem nenhum mecanismo de freshness para skill files (apenas para plugins)
- Não existe padrão estabelecido para "skill drift detection" no ecossistema de LLM tools
- O `SessionStart` hook existe e pode rodar git, mas ninguém (até onde se sabe) construiu um skill freshness checker usando ele
- A combinação `SessionStart` + git hash comparison + sidecar file (`.synced-commit`) preenche exatamente o gap entre "plugin system com SHA pinning" e "skill files sem nenhum tracking"

## Hipótese

Um script bash registrado como `SessionStart` hook em `~/.claude/settings.json` — filtrado para `source: startup` — pode comparar o git SHA da última alteração na pasta `commands/` do clone local do `claude-kickstart` contra o SHA registrado em `~/.claude/commands/.synced-commit`, e emitir uma única linha de aviso quando divergirem. O check roda em <500ms (fetch com `timeout 2`; hash read de ref cache local). Isso é notify-only: o fix é um comando explícito `sync-skills`.

**Como chegamos aqui:**
- Descartado: auto-update — risco de sessão mid-flight com skills inconsistentes; um bad commit no source corromperia todas as máquinas imediatamente
- Descartado: semver + version bumps em cada skill — sobrecarga de manutenção incompatível com markdown puro; humans esquecem bumps
- Descartado: comparação de hash de conteúdo de arquivo — false positives de whitespace/CRLF; não detecta arquivos deletados; O(n) reads

**Stress-test:** O ponto mais fraco é o clone local ficar stale ele mesmo. Se `git fetch` falha silenciosamente (rede, firewall, rate limit), o check compara contra refs locais cacheadas que nunca avançam — dá false confidence de freshness por tempo indefinido. Isso é mitigável (logar se `timeout` disparou, checar data do último fetch bem-sucedido) mas nunca elimina o risco completamente.

## Próxima ação

**Veredicto:** Melhoria em existente (nova feature no sistema de skills do claude-terminal / global claude config)

**Próxima skill:** `/start-feature --discover skill-freshness-check`
**Nome sugerido:** `skill-freshness-check`

**O que ficou consolidado:**
- **Source of truth:** clone local de `rmolines/claude-kickstart` + `timeout git fetch` no check — não direto no GitHub API (rate limit 60req/hr unauthenticated)
- **Staleness signal:** SHA do último commit que tocou `commands/` no clone vs SHA registrado em `.synced-commit` (escrito apenas após sync bem-sucedido)
- **5 failure modes a guardar:** (1) clone nunca atualizado → false confidence; (2) `.synced-commit` escrito antes do rsync terminar → drift local invisível; (3) arquivos deletados na source não detectados se check só itera arquivos locais; (4) hook não registrado em sessões de projeto com `settings.json` próprio; (5) hash de commit ≠ hash de conteúdo — revert para estado idêntico gera warning espúrio

---

Faça `/clear` para limpar a sessão e então rode a próxima skill com o slug `skill-freshness-check`.
O contexto está preservado em `.claude/feature-plans/skill-freshness-check/explore.md`.

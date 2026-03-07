# Discovery: skill-freshness-check
_Gerado em: 2026-03-05_

## Problema real

Skills locais em `~/.claude/commands/` derivam silenciosamente da fonte de verdade (`rmolines/claude-kickstart`) sem nenhum sinal. O usuário não sabe, ao iniciar uma sessão, se está operando com skills atuais ou defasadas. O drift pode acumular por dias ou semanas sem aviso.

## Usuário / contexto

Dev solo usando Claude Code como força multiplicadora em múltiplos ambientes de trabalho. Skills são o "sistema operacional" do workflow — uma skill desatualizada silenciosamente produz comportamento incorreto sem nenhuma evidência de que isso está acontecendo.

## Decisão de arquitetura: manter sistema atual, não migrar para plugins

Investigado o sistema oficial de plugins da Anthropic. Três gaps bloqueiam migração:

| Gap | Detalhe |
|---|---|
| Namespace obrigatório | Commands ficam `/kickstart:ship-feature` — `/ship-feature` curto não é suportado, by design |
| Sem especialização por projeto | Plugin global não pode ser customizado por projeto (feature request #11461, aberta, sem prazo) |
| Auto-update de third-party quebrado | Issue #26744 — marketplaces customizados no GitHub não atualizam automaticamente |

**Conclusao:** o sistema atual (`~/.claude/commands/` + kickstart + sync-skills) suporta casos de uso que plugins não suportam hoje. A arquitetura está certa — o que falta é deteccao de drift.

## Alternativas consideradas

| Opcao | Por que nao basta |
|---|---|
| Migrar para plugin system da Anthropic | Namespace obrigatório quebra nomes curtos; sem especialização por projeto; auto-update third-party quebrado |
| SHA do último commit que tocou `commands/` | Proxy incorreto: rebase/cherry-pick avancam SHA sem mudar conteudo; revert para estado identico gera falso positivo |
| Clone local como unica fonte de verdade | Clone pode ficar stale — false confidence sem fetch bem-sucedido |
| Gate de 24h antes de fazer fetch | Rejeitado pelo usuario — quer check a todo startup |

## Por que agora

Skills sao o mecanismo central de qualidade do workflow. Drift silencioso significa trabalho feito com instrucoes erradas, sem saber. O problema cresce proporcionalmente com a frequencia de edicao de skills.

## Escopo da feature

### Dentro

- Script bash em `~/.claude/hooks/session-start-freshness.sh`
- Registrado como `SessionStart` hook em `~/.claude/settings.json` (escrita atomica)
- Roda a todo startup (source: startup — nao resume, nao clear)
- Faz `timeout 3 git fetch origin` no clone local de `claude-kickstart`
- Compara hash de conteudo de cada `.md` em `commands/` (nao SHA de commit)
- Detecta arquivos deletados na source que ainda existem localmente
- Emite aviso em **stderr** (vai direto ao terminal do usuario, nao depende do Claude mencionar)
- Injeta resumo minimo em **stdout** para o Claude ter contexto do estado
- Se fetch falhar (timeout, sem rede): emite aviso explicito de "check inconclusivo" — nunca false confidence
- Aponta para `sync-skills` como comando de remediacao

### Fora (explicito)

- Auto-update: nao aplica mudancas automaticamente — notify-only por design
- Mudancas em Swift (HookHandler, IPCProtocol, AgentEventType): escopo A escolhido, zero mudancas no app
- Gate de 24h: rejeitado — roda a todo startup
- Skills de projeto (`.claude/commands/`): escopo inicial cobre apenas global (`~/.claude/commands/`)
- Instalacao automatica do clone: usuario deve ter o clone em path configuravel

## Criterio de sucesso

- Ao iniciar uma sessao com skills locais defasadas: aviso aparece no terminal antes do primeiro prompt
- Ao iniciar uma sessao com skills em dia: zero output (silencioso)
- Se fetch falhar: mensagem explicita de incerteza, nunca silencio enganoso
- Tempo de execucao total do hook: < 4s (3s timeout do fetch + overhead minimo)

## Riscos identificados

| Risco | Mitigacao |
|---|---|
| `timeout` nao e nativo no macOS (e `gtimeout` do coreutils) | Detectar disponibilidade; fallback para subshell com `( git fetch & sleep 3; kill %1 ) 2>/dev/null` |
| Clone local inexistente ou em path desconhecido | Guard no inicio do script: se clone nao existe, emite instrucao de setup e sai |
| `.synced-commit` escrito antes do rsync terminar | Escrita atomica via `.tmp` + `mv`; escrever SOMENTE apos sync completo bem-sucedido |
| Arquivos deletados na source nao detectados | Comparar lista de arquivos (diff de nomes) alem de hash de conteudo |
| settings.json malformado quebra Claude Code no startup | Escrita atomica: escrever em `.tmp`, validar com `python3 -m json.tool`, so entao `mv` para o definitivo |
| Aviso a todo startup sendo ignorado (fadiga) | Aviso so aparece quando ha drift real — silencio quando tudo ok reduz fadiga |
| `sync-skills` como comando de remediacao pode nao existir ou ter nome diferente | Verificar existencia antes de referenciar; mostrar o comando raw de fallback tambem |

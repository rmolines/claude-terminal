# Plan: skill-freshness-check

## Problema

Skills locais em `~/.claude/commands/` derivam silenciosamente da fonte de verdade
(`rmolines/claude-kickstart`) sem nenhum sinal. O usuário não sabe, ao iniciar uma sessão,
se está operando com skills atuais ou defasadas. O drift pode acumular por dias ou semanas
sem aviso.

## Assunções

<!-- status: [assumed] = não verificada | [verified] = confirmada | [invalidated] = refutada -->
<!-- risco:   [blocking] = falsa bloqueia a implementação | [background] = emerge naturalmente -->

- [verified][blocking] Clone local de `claude-kickstart` existe em `/Users/rmolines/git/claude-kickstart/`
- [verified][blocking] `matcher: "startup"` filtra apenas novos startups (não resume/clear) — confirmado na pesquisa
- [verified][background] `~/.claude/hooks/` não existe — precisa ser criado com `mkdir -p`
- [assumed][background] `shasum -a 256` disponível (padrão macOS via Perl)
- [assumed][background] `jq` disponível no ambiente Claude Code (para modificar settings.json)

## Questões abertas

**A implementação vai responder (monitorar):**

- Bug #13650 (stdout de SessionStart pode ser dropado): verificar se o contexto chega ao
  Claude na primeira sessão de teste; se não chegar, stdout é secundário e stderr é suficiente.

**Explicitamente fora do escopo (evitar scope creep):**

- Auto-update: feature é notify-only — nunca aplica mudanças automaticamente
- Skills de projeto (`.claude/commands/` no repo): cobre apenas global (`~/.claude/commands/`)
- Instalação automática do clone de kickstart: usuário deve ter o clone em path configurável

## Deliverables

### Deliverable 1 — Script funcional (walking skeleton)

**O que faz:** Script existe, é executável, lê stdin (python3), detecta `source != startup` e
sai silenciosamente, faz `git fetch` com timeout portável (`$BASHPID`), lista arquivos em
`origin/main:.claude/commands/` via `git ls-tree`. Output mínimo em stderr para confirmar
funcionamento.

**Critério de done:**

```bash
echo '{"source":"startup","session_id":"test"}' | bash ~/.claude/hooks/session-start-freshness.sh
# termina sem erro; git ls-tree executa
echo '{"source":"resume","session_id":"test"}' | bash ~/.claude/hooks/session-start-freshness.sh
# termina silenciosamente (source != startup)
```

**Valida:** padrão de timeout com `$BASHPID`, `git ls-tree` contra clone local, parse de stdin,
guard de KICKSTART_DIR.

**Deixa aberto:** lógica de hash comparison, output formatado para o usuário, registro no
settings.json.

**Execute `/checkpoint` antes de continuar para o Deliverable 2.**

### Deliverable 2 — Lógica completa + registro no settings.json

**O que faz:** Hash comparison completo (modificado/novo no remote/deletado do remote), output
formatado em stderr com lista de arquivos divergentes + instrução de remediação, contexto
mínimo em stdout para o Claude, lógica de "check inconclusivo" quando fetch falha, registro
no `~/.claude/settings.json` via escrita atômica.

**Critério de done:**

- Com skills em dia: zero output ao iniciar nova sessão Claude Code (silencioso)
- Com skill modificada localmente: aviso aparece em stderr antes do primeiro prompt
- Se fetch falha (ex: sem rede): mensagem explícita de "check inconclusivo", nunca silêncio
- `~/.claude/settings.json` tem o hook registrado:
  ```bash
  python3 -m json.tool ~/.claude/settings.json | grep -A8 "SessionStart"
  ```

**Valida:** algoritmo de hash diff (modificado/novo/deletado), escrita atômica de
settings.json, comportamento em falha de fetch.

## Arquivos a criar/modificar

- `~/.claude/hooks/session-start-freshness.sh` — criar (diretório ainda não existe)
- `~/.claude/settings.json` — adicionar entrada `SessionStart` (escrita atômica obrigatória)

**Nota:** ambos os arquivos são globais (fora de qualquer repo git). A worktree serve como
staging e documentação do plano.

## Passos de execução

### Deliverable 1

1. Criar `~/.claude/hooks/` com `mkdir -p ~/.claude/hooks/` [D1]
2. Criar `~/.claude/hooks/session-start-freshness.sh` com: [D1]
   - `#!/bin/bash` + `set -euo pipefail`
   - Leitura de stdin: `INPUT=$(cat)`
   - Parse de `source` via python3 — sair silenciosamente se `source != "startup"`
   - Guard: verificar `$CLAUDE_KICKSTART_DIR` ou default `/Users/rmolines/git/claude-kickstart`;
     se não existir → stderr "AVISO: clone de kickstart não encontrado em $KICKSTART_DIR" + exit 0
   - `fetch_with_timeout()`: subshell com `$BASHPID` kill, `GIT_TERMINAL_PROMPT=0`,
     `GIT_SSH_COMMAND="ssh -o ConnectTimeout=3 -o BatchMode=yes"`, timeout 3s
   - Chamar `fetch_with_timeout` e capturar status
   - `git -C "$KICKSTART_DIR" ls-tree --name-only origin/main -- .claude/commands/ | grep '\.md$'`
3. `chmod +x ~/.claude/hooks/session-start-freshness.sh` [D1]
4. Testar: [D1]
   ```bash
   echo '{"source":"startup","session_id":"test"}' | bash ~/.claude/hooks/session-start-freshness.sh
   echo '{"source":"resume","session_id":"test"}' | bash ~/.claude/hooks/session-start-freshness.sh
   ```
5. **Execute `/checkpoint` — Deliverable 1 concluído**

### Deliverable 2

6. Adicionar função `hash_content()`: `shasum -a 256 | awk '{print $1}'` com fallback para
   `sha256sum` se shasum não disponível [D2]
7. Adicionar loop de comparação para cada arquivo listado pelo `git ls-tree`: [D2]
   - Hash do arquivo no remote: `git -C "$KICKSTART_DIR" show "origin/main:.claude/commands/$file" | hash_content`
   - Hash do arquivo local: `shasum -a 256 "$HOME/.claude/commands/$file" 2>/dev/null | awk '{print $1}'`
   - Classificar: `modified` (hashes diferem), `missing_locally` (não existe em `~/.claude/commands/`)
8. Adicionar detecção de arquivos deletados no remote: arquivos em `~/.claude/commands/*.md`
   que NÃO aparecem na lista do `git ls-tree` → `deleted_upstream` [D2]
9. Gerar output em stderr se houver drift: [D2]
   ```
   [skill-freshness] AVISO: skills desatualizadas detectadas
     modified: ship-feature.md, close-feature.md
     missing_locally: new-skill.md
     deleted_upstream: old-skill.md
   Rode: git -C /Users/rmolines/git/claude-kickstart pull && sync-skills
   ```
10. Injetar contexto em stdout (JSON `hookSpecificOutput.additionalContext` ou plain-text
    como fallback por causa do bug #13650): status geral + lista de arquivos com drift [D2]
11. Adicionar caso de fetch inconclusivo: se `fetch_with_timeout` falhar → stderr
    `[skill-freshness] AVISO: check inconclusivo — git fetch falhou (sem rede ou timeout)` [D2]
12. Registrar o hook em `~/.claude/settings.json` via escrita atômica: [D2]
    ```bash
    tmpfile=$(mktemp "$HOME/.claude/settings.json.XXXXXX.tmp")
    jq '.hooks.SessionStart += [{"matcher":"startup","hooks":[{"type":"command","command":"~/.claude/hooks/session-start-freshness.sh","async":true}]}]' \
      "$HOME/.claude/settings.json" > "$tmpfile"
    python3 -m json.tool "$tmpfile" > /dev/null  # validar JSON
    mv "$tmpfile" "$HOME/.claude/settings.json"
    ```
13. Verificar settings.json: `python3 -m json.tool ~/.claude/settings.json | grep -A8 SessionStart` [D2]
14. Testar end-to-end: iniciar nova sessão Claude Code e observar stderr antes do primeiro prompt [D2]

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não (instalação manual nesta sessão)
- [ ] CI/CD: não muda (arquivos globais, fora do repo)
- [ ] Config principal: `~/.claude/settings.json` — adicionar entrada `SessionStart`
- [ ] Novas dependências: não (`bash`, `git`, `python3`, `shasum`, `jq` já disponíveis)

## Rollback

```bash
# Remover o hook do settings.json
python3 -c "
import json, os
p = os.path.expanduser('~/.claude/settings.json')
with open(p) as f: s = json.load(f)
s.get('hooks', {}).pop('SessionStart', None)
with open(p, 'w') as f: json.dump(s, f, indent=2)
print('SessionStart hook removido.')
"

# Remover o script
rm ~/.claude/hooks/session-start-freshness.sh
```

## Learnings aplicados

- **CVE-2025-59536**: hook logic em script externo (`~/.claude/hooks/`) — auditável, nunca
  inline no settings.json
- **Escrita atômica de settings.json**: obrigatório conforme CLAUDE.md — `mktemp` no mesmo
  filesystem + `mv` (rename(2) atômico no APFS)
- **`timeout` não existe no macOS**: padrão `$BASHPID` subshell kill em vez de
  `timeout`/`gtimeout` (requer Homebrew)
- **stdout de SessionStart pode ser dropado (#13650)**: aviso principal vai em stderr
  (imune ao bug); stdout é contexto secundário para o Claude

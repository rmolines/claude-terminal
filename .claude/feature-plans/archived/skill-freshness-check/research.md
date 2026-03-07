# Research: skill-freshness-check

## Descrição da feature

Hook bash `SessionStart` que roda a todo novo startup de sessão Claude Code,
compara o conteúdo de `~/.claude/commands/*.md` contra `origin/main` do clone
local de `rmolines/claude-kickstart`, e emite aviso em stderr se houver drift.
Silencioso quando tudo está em dia.

## Arquivos existentes relevantes

- `~/.claude/settings.json` — onde o hook será registrado (seção `hooks.SessionStart`)
- `/Users/rmolines/git/claude-kickstart/` — clone local da fonte de verdade (encontrado)
- `/Users/rmolines/git/claude-kickstart/.claude/commands/` — referência upstream
- `/Users/rmolines/git/claude-kickstart/.claude/hooks/pre-tool-use.sh` — único hook existente; padrão canônico a seguir
- `~/.claude/hooks/` — **não existe ainda**; precisa ser criado como parte desta feature

## Padrões identificados

### Formato do hook no settings.json

Para SessionStart com filtro só em `startup` (não resume/clear):

```json
"SessionStart": [
  {
    "matcher": "startup",
    "hooks": [
      {
        "type": "command",
        "command": "~/.claude/hooks/session-start-freshness.sh",
        "async": true
      }
    ]
  }
]
```

- `async: true` → fire-and-forget; Claude Code não espera o resultado para iniciar a sessão
- `matcher: "startup"` → filtra no campo `source` do JSON de stdin (valores: `startup`, `resume`, `clear`, `compact`)
- Sem `matcher` → rodaria em todo evento SessionStart (incluindo /clear e resume)

### Estrutura do stdin do hook

```json
{
  "session_id": "abc123",
  "transcript_path": "/Users/.../.claude/projects/.../session.jsonl",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "SessionStart",
  "source": "startup",
  "model": "claude-sonnet-4-6"
}
```

### Canais de saída

- **stderr** → exibido diretamente ao usuário no terminal (aviso de drift, instrução de remediação)
- **stdout (plain text)** → injetado como contexto para o Claude
- **stdout (JSON `hookSpecificOutput.additionalContext`)** → injetado com estrutura; preferível para o contexto do Claude
- **Exit 2** → stderr vai ao usuário; SessionStart não pode bloquear de nenhuma forma

Bug conhecido (GitHub #13650): stdout de SessionStart pode ser silenciosamente dropado.
Mitigação: testar com plain-text stdout antes de usar JSON; o aviso em stderr não é afetado.

### Padrão canônico de hook (de pre-tool-use.sh do kickstart)

```bash
#!/bin/bash
set -euo pipefail

INPUT=$(cat)
# Parsear com python3 (sem dependência de jq)
FIELD=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('field',''))" <<< "$INPUT")
```

## Algoritmo de detecção de drift

### Fonte de verdade

Após `git fetch origin` no clone local, usar `git ls-tree` e `git show` para ler
os arquivos diretamente do object store do git — sem precisar fazer checkout.

```bash
# Listar arquivos .md em origin/main:.claude/commands/
git -C "$KICKSTART_DIR" ls-tree --name-only origin/main -- .claude/commands/ \
  | grep '\.md$'

# Hash de um arquivo no remote
git -C "$KICKSTART_DIR" show "origin/main:.claude/commands/$file" | shasum -a 256 | awk '{print $1}'

# Hash do arquivo local
shasum -a 256 "$HOME/.claude/commands/$file" | awk '{print $1}'
```

Isso detecta:
- Arquivo modificado (hashes diferem)
- Arquivo novo no remote que não existe localmente
- Arquivo deletado no remote que ainda existe localmente

### Hashing cross-platform (macOS + Linux)

```bash
hash_content() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    sha256sum | awk '{print $1}'
  fi
}
```

`shasum -a 256` é o padrão mais portável: presente no macOS (via Perl) e Linux.
Evitar `md5sum` (não existe no macOS) e `sha256sum` (não existe no macOS).

### Timeout para git fetch (macOS — sem GNU coreutils)

`timeout` não existe no macOS. `gtimeout` requer Homebrew coreutils (não garantido).
Solução portável com `$BASHPID` (bash 3.2+ compatível, inclui `/bin/bash` do macOS):

```bash
fetch_with_timeout() {
  local timeout=3
  (
    cmdpid=$BASHPID
    (sleep "$timeout"; kill "$cmdpid" 2>/dev/null) &
    watchpid=$!
    GIT_TERMINAL_PROMPT=0 \
      GIT_SSH_COMMAND="ssh -o ConnectTimeout=3 -o BatchMode=yes" \
      git -C "$KICKSTART_DIR" fetch origin --quiet 2>/dev/null
    local status=$?
    kill "$watchpid" 2>/dev/null
    wait "$watchpid" 2>/dev/null
    return $status
  )
}
```

- `GIT_TERMINAL_PROMPT=0` → impede git de travar em prompt de senha
- `ssh -o ConnectTimeout=3 -o BatchMode=yes` → timeout de handshake SSH
- O `BASHPID` subshell kill é o fallback para o caso geral (HTTPS, proxy, etc.)

### Escrita atômica do settings.json

```bash
update_settings_atomically() {
  local settings="$HOME/.claude/settings.json"
  local tmpfile
  # mktemp no MESMO diretório → mesmo filesystem → mv é atômico (rename(2) no APFS)
  tmpfile=$(mktemp "${settings}.XXXXXX.tmp")

  # Modificar com jq (Claude Code depende de jq; pode assumir presença)
  jq 'EXPRESSION' "$settings" > "$tmpfile"

  # Validar JSON antes de substituir
  if ! python3 -m json.tool "$tmpfile" > /dev/null 2>&1; then
    rm -f "$tmpfile"
    echo "ERRO: JSON inválido, settings.json não foi modificado" >&2
    return 1
  fi

  mv "$tmpfile" "$settings"
}
```

Regra do CLAUDE.md: nunca escrever diretamente em `settings.json` — sempre via `replaceItem`/mv atômico.

## Dependências externas

- `bash` — shebang `/bin/bash`, versão 3.2+ (padrão macOS)
- `git` — necessário; clone local deve existir
- `python3` — para parse de JSON e validação; pré-instalado no macOS
- `shasum` — para hashing; pré-instalado no macOS via Perl
- `jq` — para modificar settings.json; presente no ambiente Claude Code
- Clone local de `rmolines/claude-kickstart` — path configurável via `$CLAUDE_KICKSTART_DIR`

## Hot files que serão tocados

- `~/.claude/settings.json` — adicionar entrada `SessionStart` [⚠️ escrita atômica obrigatória]
- `~/.claude/hooks/session-start-freshness.sh` — criar (diretório não existe ainda)

Nenhum arquivo do app Swift ou do repo `claude-terminal` é tocado.

## Riscos e restrições

| Risco | Mitigação |
|---|---|
| `~/.claude/hooks/` não existe | Criar com `mkdir -p` no início da instalação |
| `timeout` não disponível no macOS | Padrão `$BASHPID` subshell kill (portável, bash 3.2+) |
| Clone inexistente ou path desconhecido | Guard no início do script: verificar `$KICKSTART_DIR`, emitir instrução de setup e sair sem falha |
| settings.json malformado quebra Claude Code | Validar com `python3 -m json.tool` + `mv` atômico; nunca escrever diretamente |
| Fetch falha (offline, timeout) | Emitir aviso explícito de "check inconclusivo" + timestamp; nunca silencio enganoso |
| `sync-skills` não existe globalmente | `sync-skills.md` é comando de projeto (kickstart); remediation message deve apontar para `git -C "$KICKSTART_DIR" pull` como alternativa |
| stdout de SessionStart dropado (#13650) | Aviso principal vai em stderr (imune ao bug); stdout é contexto secundário para o Claude |
| Hook roda em resume/clear (indesejado) | `matcher: "startup"` filtra só novos startups |
| Arquivos extras locais (customizações) | Não tratar como erro — apenas reportar arquivos não presentes no upstream |

## Fontes consultadas

- `~/.claude/settings.json` (leitura direta — estrutura de hooks existentes)
- `/Users/rmolines/git/claude-kickstart/.claude/hooks/pre-tool-use.sh` (padrão canônico)
- [Claude Code Hooks Docs](https://code.claude.com/docs/en/hooks) (via web search)
- GitHub issues #10373 e #13650 (SessionStart stdout bug)
- [BashFAQ/068](https://mywiki.wooledge.org/BashFAQ/068) (timeout portável)
- [shasum man page macOS](https://ss64.com/mac/shasum.html)

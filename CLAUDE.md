# CLAUDE.md — Claude Terminal

## Visão geral

**Claude Terminal** é um app macOS nativo que funciona como Mission Control para uma squad
de agentes Claude Code rodando em paralelo. Em vez de gerenciar N janelas de terminal
empilhadas, o dev cria tasks, acompanha progresso em tempo real e aprova pedidos HITL sem
quebrar o foco.

**WHY:** Dev solo usando Claude Code como força multiplicadora não tem interface projetada para
esse workflow — tem um amontoado de terminais de texto e zero contexto sobre o que cada agente
está fazendo.

**WHAT:** Dashboard com status de cada agente (tokens, fase da skill, sub-agentes em
background), menu bar com badge de HITL pendentes, backlog de tasks persistente (SwiftData),
e terminal opcional para inspecionar a sessão raw do Claude Code.

**HOW:** Claude Code hooks → `ClaudeTerminalHelper` (thin CLI, lê stdin JSON) → Unix domain
socket → `HookIPCServer` (actor) → `SessionManager` (actor) → `@MainActor` → SwiftUI.

## Stack

- **Swift 6.2** com `defaultIsolation = MainActor` em todos os targets
- **SwiftUI 70% + AppKit 30%** — NSStatusItem manual, NSPanel para HUD flutuante
- **SwiftTerm** (`LocalProcessTerminalView`) — PTY engine, uma `DispatchQueue` por instância
- **SwiftData** para entidades de negócio (ClaudeTask, ClaudeAgent); Core Data para event streams de alta frequência
- **SecureXPC** — IPC tipado entre app e helper com verificação por audit token (não PID)
- **Unix Domain Socket** — hooks → app, latência ~2-5µs, `~/Library/Application Support/ClaudeTerminal/hooks.sock`
- Distribuição: DMG notarizado via `xcrun notarytool`, fora da App Store
- CI: `swift build` em `macos-15`; Release: `swift build -c release` → bundle manual → sign Developer ID → notarize → DMG

## Critical rules — NEVER do without explicit approval

- Nunca commit de tokens, keys ou passwords — usar env vars ou secret managers
- Nunca force-push para main — sempre PRs com CI verde
- Nunca `--no-verify` em hooks — corrigir o problema subjacente
- Nunca modificar `~/.claude/settings.json` sem escrita atômica (`replaceItem`) — TOCTOU
- Nunca passar args de hook diretamente para shell — sempre allowlist (CVE-2025-59536)
- Nunca usar PID para validar identidade XPC — audit token obrigatório

## Feature workflow

1. `/start-feature <nome>` — intake + hot files → worktree → plano
2. Implementar no worktree em `.claude/worktrees/<nome>`
3. `/ship-feature` — build + tests + PR
4. `/close-feature` — cleanup + LEARNINGS.md

## Hot files — ler SEMPRE antes de planejar qualquer feature

| Arquivo | Por quê |
|---|---|
| `Shared/IPCProtocol.swift` | Contrato entre app e helper — mudanças afetam ambos os targets |
| `ClaudeTerminal/Services/HookIPCServer.swift` | Critical path de todos os eventos dos agentes |
| `ClaudeTerminal/Services/SessionManager.swift` | Actor central — estado mutável de sessões ativas |
| `ClaudeTerminal/Models/ClaudeTask.swift` | Schema SwiftData — mudanças requerem `VersionedSchema` |
| `ClaudeTerminal/Models/ClaudeAgent.swift` | Schema SwiftData — idem |
| `ClaudeTerminalHelper/main.swift` | Entry point do helper — afetado por mudanças de protocolo |
| `.github/workflows/release.yml` | Pipeline de notarização — ler antes de mudar targets/entitlements |
| `app.entitlements` + `helper.entitlements` | Entitlements — mudanças podem causar falha na notarização |
| `Package.swift` | Dependências e targets — mudanças afetam CI |
| `.claude/ux-identity.md` | Modelo mental + constraints de UX — ler antes de qualquer feature que toca UI |
| `.claude/ux-patterns.md` | Decision table de interações — padrões a seguir em novas views |
| `.claude/ux-screens.md` | Contrato de intenção por tela — job de cada screen |
| `.claude/commands/design-review.md` | Skill head of design — usar antes de abrir PR com mudanças de UI |

## Armadilhas conhecidas

| Componente | Armadilha | Solução |
|---|---|---|
| Claude Code hooks | `hookSpecificOutput` JSON não é suportado em `SessionStart` — retorna "hook error" mesmo com exit 0 | Usar plain text stdout para SessionStart; `hookSpecificOutput` só funciona em PreToolUse/PostToolUse |
| Claude Code hooks | Stderr de hooks não aparece no terminal mesmo com hook síncrono (não-async) | Usar `osascript` para notificações visíveis ao usuário; stderr vai para pipe não exibido |
| Claude Code hooks | `async: true` em SessionStart descarta stderr completamente (background sem terminal) | Remover `async` para que o hook seja síncrono; ou usar arquivo/notification para output ao usuário |
| Bash hook scripts | `set -euo pipefail` + `[ cond ] && cmd` — quando condição é falsa, retorna exit 1 e dispara `set -e` | Usar `if/fi` em vez de `[ ] && cmd` em scripts com `set -e`; ou remover `set -e` de hook scripts |
| SwiftData | Array ordering não preservado ao recarregar | Adicionar `sortOrder: Int` em todos os arrays |
| SwiftData | Auto-save não é confiável | Sempre `context.save()` após mutations |
| SwiftData | `ModelContext` não é thread-safe | Um contexto por actor/thread |
| SwiftData | `let` em propriedades de relacionamento crasha em runtime | Sempre `var` e optional |
| SwiftData | `Task` como nome de @Model causa conflito | Usar `ClaudeTask` |
| XPC | Validar identidade por PID é vulnerável a race condition | `xpc_connection_set_peer_code_signing_requirement` (audit token) |
| SwiftTerm | `DispatchQueue.main` compartilhada trava UI com 4+ agentes | Uma queue separada por instância de `LocalProcessTerminalView` |
| Hooks | Input não sanitizado → RCE via repo malicioso | Allowlist antes de qualquer execução (CVE-2025-59536) |
| Code signing | Ordem errada causa falha no Gatekeeper | Helper PRIMEIRO, frameworks, app por último — nunca `--deep` |
| SwiftUI @main + SPM | Conflito com `main.swift` no mesmo target | Usar `@main` OU `main.swift`, nunca ambos |
| bootstrap.yml | Só dispara no primeiro push (`run_number == 1`) | Não re-rodar manualmente |
| MCP servers no Claude Code | `settings.json` não aceita `mcpServers` (schema rejeita). Servers ficam em `~/.claude.json` | Usar `claude mcp add --scope user` para registro global; checar `~/.claude.json` no `mcpServers` key |
| `make xcode-mcp` sem `--scope user` | Sem `--scope user`, o MCP fica em scope local do projeto — não aparece em outras sessões/worktrees | Sempre passar `--scope user` ao registrar servidores MCP globais |
| gh pr merge | `--delete-branch` falha em worktree (`main` já checked out no repo pai) | Resolvido — skills usam GitHub MCP `merge_pull_request` com `deleteBranch: true` (independente de contexto de diretório) |
| `gh pr merge` sem `-R` em sessão com worktrees | `gh pr merge <N>` falha com "Could not resolve to a PullRequest" quando `gh` detecta o repo errado (ex: dentro de worktree ou sessão com múltiplos remotes) | Resolvido — skills usam GitHub MCP `merge_pull_request` com `owner`/`repo` explícitos |
| Worktree stale apontando para main | Diretório `.claude/worktrees/<nome>` existe no disco mas não aparece em `git worktree list`; `git -C` mostra HEAD no main em vez da branch da feature | Branch local ainda tem os commits — rebase + `git push --force-with-lease` direto da branch, sem precisar recriar a worktree |
| SPM executável | `@testable import` não funciona em `.executableTarget` | Mover lógica testável para `.target` (library); ou usar actor mirror local no test file |
| SPM binário (sem .app bundle) | Keyboard input não funciona — janelas não recebem events do OS | `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps: true)` em `applicationDidFinishLaunching` |
| SPM binário (sem .app bundle) | `Bundle.main.bundleIdentifier` é nil → erros de window tabs, SwiftData, notificações | Embedar `Info.plist` via linker flag: `.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "ClaudeTerminal/App/Info.plist"])` em `Package.swift` |
| NavigationSplitView sidebar | `@FocusState` + `TextField` mostra anel mas não recebe keyboard | Usar `NSViewRepresentable` com `NSTextField` que chama `window.makeFirstResponder(field)` diretamente |
| PTY environment | PATH hardcoded não inclui `~/.local/bin`, nvm, etc. | Usar `zsh -l -i -c "..."` para herdar PATH completo do usuário |
| Worktree + plan.md | Escrever `plan.md` no working tree do `main` antes de criar worktree → arquivo fica não-rastreado, bloqueia `git pull` após merge | Sempre escrever `plan.md` no path do worktree: `/worktrees/<feature>/...` |
| Implementação no main em vez do worktree | Agente implementa arquivos diretamente no `main` (sem worktree) → arquivos ficam como unstaged em `main`, precisam ser copiados manualmente para o worktree antes do commit | Sempre confirmar o CWD antes de criar arquivos: `git branch --show-current` deve retornar `feature/<nome>` |
| Curly quotes em string interpolation Swift | `"texto \(var)"` com aspas tipográficas (`"..."`) dentro do literal quebra o parser do Swift com erro críptico de `FormatStyle` | Usar aspas retas escapadas: `\"` dentro de string interpolation |
| `gh pr create` em worktree | `gh` detecta o repo errado (`claude-kickstart`) quando rodando de dentro de um worktree | Resolvido — skills usam GitHub MCP `create_pull_request` com `owner`/`repo` explícitos (independente de contexto de diretório) |
| Code blocks sem language tag em .md | Lint falha com MD040 — mesmo pseudocódigo ou texto livre dentro de ` ``` ` sem language tag | Sempre usar ` ```text ` para blocos sem linguagem específica |
| NSPanel flutuante | `hidesOnDeactivate = true` (padrão) faz o panel sumir ao trocar de app | Sempre definir `hidesOnDeactivate = false` em panels que devem persistir sobre outros apps; incluir `.fullScreenAuxiliary` no `collectionBehavior` para apps em full-screen |
| PTY colors (TUI apps) | Cores apagadas vs iTerm — `TERM=xterm-256color` não basta | Adicionar `COLORTERM=truecolor` ao env do PTY; sem ela, Claude Code (e outros TUIs) cai para paleta ANSI de 16 cores em vez de 24-bit true color |
| Worktree stale + Xcode | Diretório `.claude/worktrees/<nome>` existe no disco mas não no `git worktree list` → Xcode não consegue encontrar os arquivos fonte e falha o build com "Build input files cannot be found" | Remover o diretório stale (`rm -rf`) + limpar o derived data correspondente em `~/Library/Developer/Xcode/DerivedData/` |
| `SUPublicEDKey` placeholder pós-bootstrap | `Info.plist` sai do bootstrap com `REPLACE_WITH_PUBLIC_KEY_FROM_generate_keys` — Sparkle recusa iniciar com "The updater failed to start" sem uma chave EdDSA válida | Rodar `.build/artifacts/sparkle/Sparkle/bin/generate_keys` (NÃO `swift run generate_keys` — o pacote SPM do Sparkle é `binaryTarget` e não expõe executáveis) — retorna a chave do Keychain se já existir |
| Hook `PermissionRequest` global | Hook registrado em `~/.claude/settings.json` dispara para TODAS as sessões Claude Code da máquina, não só as do app | Usar env var `CLAUDE_TERMINAL_MANAGED=1` no PTY para identificar sessões gerenciadas; auto-aprovar silenciosamente as externas |
| `.markdownlint-cli2.yaml` sem `config:` | Criar o arquivo com só `ignores:` faz markdownlint-cli2 v0.6.0 ignorar `.markdownlint.yaml` e usar regras default — CI quebra com MD049/MD036 em arquivos intocados | Sempre incluir `config: .markdownlint.yaml` no topo do `.markdownlint-cli2.yaml` |
| Stash pop cruzado entre worktrees | `git stash pop` numa worktree/branch restaura mudanças de outra worktree — working tree fica com mais conteúdo do que o commit HEAD, silenciosamente | Sempre rodar `git diff HEAD --stat` antes de `git add` para confirmar que staged = expected |
| `List(selection:)` com @Model + `var id: UUID` | SwiftData adiciona `Identifiable` via `persistentModelID`; conflito com `var id: UUID` explícito faz cliques na List serem ignorados silenciosamente | Usar `List { ForEach { ... .onTapGesture { ... } } }` com seleção manual; `listRowBackground` para highlight |
| `ModelContainer` silenciosamente in-memory | Se o diretório pai do store URL não existe, `ModelContainer` não falha — cria store in-memory. Dados são perdidos no próximo launch sem aviso | Sempre `FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)` antes de `ModelConfiguration(url:)` |
| Agente paralelo sobrescrevendo branch | Agente A commita na branch X; agente B mergea X em main e deleta a branch. Commit do agente A fica perdido na branch deletada sem aviso | Commit ainda existe no reflog — `git cherry-pick <sha>` + nova branch a partir do main atualizado recupera tudo |
| `NSHostingView` + `rootView` durante layout cycle | Atualizar `hosting.rootView` enquanto o NSPanel está visível dispara `setNeedsUpdateConstraints()` → `postWindowNeedsUpdateConstraints`. No macOS 26, se ocorre durante um layout cycle em andamento, lança `NSException` → `EXC_BREAKPOINT`. Sintoma: crash após ~1h quando painel HITL está aberto com eventos chegando. | Cachear conteúdo atual; pular `rootView =` se sessionID + description não mudaram |
| `PermissionRequest` hook — `toolInput["description"]` não existe para Bash | Claude Code envia o comando em `toolInput["command"]`, não em `"description"`. Buscar `"description"]` retorna `nil` → painel HITL mostra "Awaiting approval" genérico em vez do comando real | Usar `toolInput["command"]` primeiro, fallback `toolInput["description"]`, fallback `toolName` |
| HITL PTY bridge — `\r` vaza para próximo dialog | Ao enviar `[0x31, 0x0d]` ao PTY para confirmar TUI dialog de permissão: `0x0d` (`\r`) fica no buffer de input e auto-confirma silenciosamente o próximo dialog antes do usuário clicar | Enviar apenas `[0x31]` — Claude Code em raw mode processa um byte de cada vez; `\r` é desnecessário e destrutivo |
| `close-feature` com paths relativos em worktree | Writes de HANDOVER.md, CHANGELOG.md etc. com path relativo dentro de `.claude/worktrees/<feature>` vão para a worktree (deletada no próximo passo) — docs perdidos, agente reescreve tudo em main | Sempre `REPO_ROOT=$(git worktree list \| head -1 \| awk '{print $1}')` no início do close-feature + usar `$REPO_ROOT/HANDOVER.md` etc. |
| `gh run list` / `gh run watch` sem `--repo` em worktree | `gh` detecta `claude-kickstart` em vez de `claude-terminal` quando rodando de dentro de uma worktree — comandos falham com HTTP 404 no repo errado | Sempre passar `--repo rmolines/claude-terminal` em todos os comandos `gh run` executados de dentro de worktrees |

## Worktree convention

- Path: `.claude/worktrees/<feature-name>`
- Branch: `feature/<feature-name>` (kebab-case)
- Sempre fazer `git fetch origin && git rebase origin/main` antes de começar

## Secrets

| Secret (GitHub Actions) | Uso |
|---|---|
| `CERTIFICATE_P12_BASE64` | Certificado Developer ID em base64 |
| `CERTIFICATE_PASSWORD` | Senha do .p12 |
| `KEYCHAIN_PASSWORD` | Senha do keychain temporário no CI |
| `APPLE_ID` | Apple ID para notarização |
| `NOTARIZATION_PASSWORD` | App-specific password do appleid.apple.com |
| `TEAM_ID` | Team ID do Developer account |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for signing Sparkle updates |

Nenhum secret é necessário para desenvolvimento local — apenas para o pipeline de release.

## Daily commands

```bash
make help            # Lista todos os comandos disponíveis
make check           # Lint + validate
swift build          # Build local de todos os targets
swift test           # Rodar testes
```

## Design workflow

### Para corrigir UX existente (retroativo)

```text
/design-review --audit
```

Diagnóstico completo do app: avalia fluxo/navegação, informação por tela e visual/estética.
Produz um backlog priorizado de fixes. Não modifica arquivos.
Não assume que a spec está certa — avalia código e spec de forma independente.

Após o audit: para cada item do backlog:
1. Implementar a correção
2. `/design-review <NomeDaView>` → gate → se aprovado, próximo item

### Para novas views (antes de implementar)

```text
/design-review <NomeDaView>
```

Se a view não existir na spec → intake mode: entrevista estruturada que define o contrato
antes de qualquer código. Aprovado pelo dev → salvo em `ux-screens.md`.

### Durante implementação (loop visual)

```text
RenderPreview → ajusta → RenderPreview → (satisfeito) → /design-review <View>
```

Usar `RenderPreview` do Xcode MCP para iterar visualmente antes do gate final.

### Gate obrigatório antes do PR

```text
/design-review <NomeDaView>
```

1. Ler `.claude/ux-identity.md` + `.claude/ux-screens.md` da(s) tela(s) afetada(s)
2. Verificar padrões aplicáveis em `.claude/ux-patterns.md`
3. Executar `/design-review <NomeDaView>` — veredito APROVADO é requisito para abrir PR

### Audit periódico (por milestone)

```text
/design-review --holistic
```

Após fechar um milestone: auditoria sistêmica de navegação, consistência de padrões
e constraints. Complementar ao `--audit` — foco em coerência do sistema, não em fixes.

## Desenvolvimento com Xcode MCP

Xcode 26.3 expõe `xcrun mcpbridge` como MCP server, dando ao Claude acesso a ferramentas
de build, testes e SwiftUI previews sem sair da sessão.

### Setup (uma vez por máquina)

```bash
make xcode-mcp
```

### Pré-requisito por sessão

Abra o projeto no Xcode antes de iniciar uma sessão de desenvolvimento:

```bash
open Package.swift   # Xcode abre o SPM package — mcpbridge conecta a esse processo
```

### Ferramentas disponíveis

| Ferramenta | O que faz |
|---|---|
| `BuildProject` | Compila o projeto e retorna erros estruturados |
| `GetBuildLog` | Lê o log de build completo após um `BuildProject` |
| `RunAllTests` / `RunSomeTests` | Roda a suite de testes e retorna resultado por teste |
| `RenderPreview` | Renderiza um `#Preview` block e retorna como imagem — ver UI sem rodar o app |
| `XcodeListNavigatorIssues` | Lista warnings e erros em tempo real do Issue Navigator |
| `XcodeRefreshCodeIssuesInFile` | Força re-análise de um arquivo específico |
| `DocumentationSearch` | Busca na documentação da Apple (SwiftUI, AppKit, SwiftData, etc.) |

### Armadilha: previews com PTY

`TerminalViewRepresentable` detecta o canvas via `XCODE_RUNNING_FOR_PREVIEWS=1` e exibe
um placeholder em vez de spawnar `/bin/zsh`. Views que embedam `AgentTerminalView` ou
`SpawnedAgentView` são seguras para `RenderPreview`.

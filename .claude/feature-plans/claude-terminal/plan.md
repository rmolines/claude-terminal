# Plano de Bootstrap — Claude Terminal
_Gerado em: 2026-02-27_

---

## Estrutura de diretórios

```
claude-terminal/
├── .claude/
│   ├── commands/                      # overrides de skills específicos do projeto
│   │   ├── start-feature.md           # ← criar (override local)
│   │   ├── ship-feature.md            # ← criar (override local)
│   │   └── close-feature.md           # ← criar (override local)
│   ├── hooks/                         # ← vem do template (não criar)
│   ├── rules/                         # ← vem do template (não criar)
│   └── settings.json                  # ← vem do template (não criar)
├── .github/
│   └── workflows/
│       ├── ci.yml                     # ← vem do template (não criar)
│       ├── bootstrap.yml              # ← vem do template (não criar)
│       └── release.yml                # ← criar (build + notarize + DMG)
├── memory/MEMORY.md                   # ← vem do template (não criar)
├── ClaudeTerminal.xcodeproj/          # ← criar via Xcode
├── ClaudeTerminal/                    # Target: app principal
│   ├── App/
│   │   ├── ClaudeTerminalApp.swift
│   │   └── AppDelegate.swift
│   ├── Features/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   └── AgentRowView.swift
│   │   ├── TaskBacklog/
│   │   │   ├── TaskBacklogView.swift
│   │   │   └── NewTaskSheet.swift
│   │   ├── HITL/
│   │   │   ├── HITLPanelView.swift
│   │   │   └── ApprovalRequestView.swift
│   │   └── Terminal/
│   │       └── TerminalViewRepresentable.swift
│   ├── Models/
│   │   ├── ClaudeTask.swift           # @Model — Task (evitar Task, conflito com Swift)
│   │   ├── ClaudeAgent.swift          # @Model — Agent
│   │   └── AgentEvent.swift           # @Model — eventos (usar Core Data direto para streams)
│   ├── Services/
│   │   ├── HookIPCServer.swift        # Unix domain socket server
│   │   ├── SessionManager.swift       # actor — gerencia PTY sessions
│   │   ├── WorktreeManager.swift      # git worktree create/cleanup
│   │   ├── SettingsWriter.swift       # escrita atômica em ~/.claude/settings.json
│   │   └── NotificationService.swift  # UNUserNotificationCenter
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
├── ClaudeTerminalHelper/              # Target: helper binary (thin CLI)
│   ├── main.swift
│   ├── HookHandler.swift
│   └── IPCClient.swift
├── Shared/                            # Target: lib compartilhada (app + helper)
│   ├── IPCProtocol.swift
│   └── AgentEventType.swift
├── ClaudeTerminalTests/               # Target: unit tests
│   └── SessionManagerTests.swift
├── ClaudeTerminalUITests/             # Target: UI tests (opcional v1)
├── ExportOptions.plist                # Para xcodebuild -exportArchive
├── app.entitlements                   # Entitlements do app principal
├── helper.entitlements                # Entitlements do helper binary
├── CLAUDE.md                          # ← vem do template, preencher TODOs
├── HANDOVER.md                        # ← vem do template (não criar)
├── LEARNINGS.md                       # ← vem do template (não criar)
└── Makefile                           # ← vem do template (adicionar targets macOS)
```

> **Nota:** `.gitignore`, `.markdownlint.yaml`, `Makefile`, `HANDOVER.md`, `LEARNINGS.md`,
> `CODEOWNERS`, `dependabot.yml`, `template-sync.yml` e `bootstrap.yml` vêm do template
> `rmolines/claude-kickstart`. Não criar manualmente.

> **Nota Xcode:** o `ClaudeTerminal.xcodeproj` é criado via `File → New → Project` no Xcode
> após o clone. O template não tem suporte a projetos Xcode — essa é a única exceção
> onde um arquivo "grande" é criado manualmente.

---

## Decisões arquiteturais

| Decisão | Escolha | Alternativa considerada | Motivo |
|---|---|---|---|
| Swift version | Swift 6.2 + `defaultIsolation = MainActor` | Swift 5.10 com strict-concurrency | Elimina a maioria dos erros de cross-actor sem mudança incremental |
| IPC hooks → app | Unix Domain Socket (`hooks.sock`) | XPC Service | Latência ~2-5µs, sem sandbox restriction, API simples |
| IPC app → helper | SecureXPC (certificado, não PID) | Unix socket bidirecional | Type-safety + verificação de identidade contra PID reuse attack |
| Terminal engine | SwiftTerm `LocalProcessTerminalView` | libghostty | API estável, mantida, apps em produção; libghostty é fork privado com API interna |
| Persistência de entidades | SwiftData com `VersionedSchema` | Core Data puro | Menos boilerplate; VersionedSchema desde v1 evita dívida de migração |
| Persistência de event streams | Core Data diretamente (não SwiftData) | SQLite.swift, GRDB | SwiftData tem performance insatisfatória para inserts massivos em alta frequência |
| Helper lifecycle | `SMAppService` (macOS 13+) | `SMJobBless` (deprecated) | API moderna, sem privilégio elevado desnecessário |
| Helper localização | Dentro do bundle (`Contents/MacOS/`) | `/usr/local/bin` | Verificação de assinatura antes de executar; imune a substituição por processo externo |
| Distribuição | DMG notarizado (fora da App Store) | App Store | PTY requer ausência de sandbox; App Store incompatível |
| Licença | Apache 2.0 | MIT, AGPL | Mais proteção de patentes que MIT; sem copyleft agressivo do AGPL (compatível com uso comercial futuro) |
| Modelo SwiftData | `ClaudeTask` (não `Task`) | `Task` | `Task` conflita com Swift Concurrency — nome reservado |

---

## CLAUDE.md do projeto

Conteúdo para preencher as seções `<!-- TODO -->` do CLAUDE.md do template:

```markdown
## Visão geral

**Claude Terminal** é um app macOS nativo que funciona como Mission Control para uma squad de
agentes Claude Code rodando em paralelo. Em vez de gerenciar N janelas de terminal empilhadas,
o dev cria tasks, acompanha progresso em tempo real e aprova pedidos HITL sem sair do contexto.

**WHY:** Dev solo usando Claude Code como força multiplicadora não tem interface projetada para
esse workflow — tem um amontoado de terminais de texto.

**WHAT:** Dashboard com status de cada agente (tokens, fase da skill, sub-agentes em background),
menu bar com badge de HITL pendentes, backlog de tasks persistente, e terminal opcional para
inspecionar a sessão raw.

**HOW:** Claude Code hooks → `claude-terminal-helper` (thin CLI) → Unix domain socket →
`HookIPCServer` (actor) → `SessionManager` (actor) → MainActor → SwiftUI.

## Stack

- **Swift 6.2** com `defaultIsolation = MainActor`
- **SwiftUI 70% + AppKit 30%** (NSStatusItem manual, NSPanel para HUD)
- **SwiftTerm** — `LocalProcessTerminalView` com DispatchQueue por instância
- **SwiftData** para entidades de negócio (Task, Agent); Core Data para event streams
- **SecureXPC** para IPC tipado entre app e helper binary
- **Unix Domain Socket** para hooks → app (latência ~2-5µs)
- Distribuição: DMG notarizado via `xcrun notarytool`
- CI: GitHub Actions em `runs-on: macos-14`

## Hot files — ler SEMPRE antes de planejar qualquer feature

| Arquivo | Por quê |
|---|---|
| `Shared/IPCProtocol.swift` | Contrato entre app e helper — qualquer mudança afeta ambos os targets |
| `ClaudeTerminal/Services/HookIPCServer.swift` | Critical path de todos os eventos dos agentes |
| `ClaudeTerminal/Services/SessionManager.swift` | Actor central — estado mutável de sessões ativas |
| `ClaudeTerminal/Models/ClaudeTask.swift` e `ClaudeAgent.swift` | Schema SwiftData — mudanças requerem `VersionedSchema` |
| `ClaudeTerminalHelper/main.swift` | Entry point do helper — afetado por qualquer mudança de protocolo |
| `.github/workflows/release.yml` | Pipeline de notarização — entender antes de mudar targets ou entitlements |
| `app.entitlements` + `helper.entitlements` | Entitlements — mudanças podem causar falha na notarização |

## Armadilhas conhecidas

| Armadilha | Sintoma | Solução |
|---|---|---|
| SwiftData array ordering | Relacionamentos embaralhados ao recarregar | Adicionar campo `sortOrder: Int` manual em todos os arrays |
| SwiftData auto-save | Dados perdidos sem aviso | Sempre chamar `context.save()` explicitamente após mutations |
| SwiftData + thread | EXC_BAD_ACCESS em runtime | Um `ModelContext` por actor/thread — nunca compartilhar |
| XPC PID validation | Vulnerável a PID reuse attack | Usar `xpc_connection_set_peer_code_signing_requirement` (audit token) |
| SwiftTerm DispatchQueue.main compartilhada | UI trava com 4+ agentes com output pesado | Uma `DispatchQueue` separada por instância de `LocalProcessTerminalView` |
| Hook input não sanitizado | RCE via repositório malicioso (CVE-2025-59536) | Validar allowlist antes de qualquer execução — nunca passar args do hook diretamente para shell |
| Code signing order | Falha na verificação do Gatekeeper | Helper PRIMEIRO, frameworks, app por último — nunca `codesign --deep` |
| `Task` como nome de @Model | Erro de compilação (conflito com Swift Concurrency) | Usar `ClaudeTask` como nome do modelo |
| Helper fora do bundle | Substituição por processo malicioso | Helper sempre em `Contents/MacOS/`; verificar assinatura antes de executar |

## Secrets e variáveis de ambiente

| Secret (GitHub) | Uso |
|---|---|
| `CERTIFICATE_P12_BASE64` | Certificado Developer ID (base64) para notarização |
| `CERTIFICATE_PASSWORD` | Senha do .p12 |
| `KEYCHAIN_PASSWORD` | Senha do keychain temporário no CI |
| `APPLE_ID` | Apple ID para notarização |
| `NOTARIZATION_PASSWORD` | App-specific password do appleid.apple.com |
| `TEAM_ID` | Team ID do Developer account |

Nenhum secret é necessário localmente para desenvolvimento — apenas para o pipeline de release.
```

---

## `.claude/commands/start-feature.md` — override local

```markdown
# /start-feature

Inicia uma nova feature no claude-terminal com worktree isolado.

## Fase A — Contexto obrigatório (ler ANTES de planejar)

Leia estes arquivos na ordem:

1. `CLAUDE.md` — visão geral, stack, armadilhas
2. `Shared/IPCProtocol.swift` — contrato IPC (afeta qualquer feature de comunicação)
3. `ClaudeTerminal/Services/SessionManager.swift` — actor central de estado
4. `ClaudeTerminal/Models/ClaudeTask.swift` e `ClaudeAgent.swift` — schema SwiftData
5. `.github/workflows/release.yml` — pipeline (relevante se a feature muda targets/entitlements)

## Fase B — Checklist de infraestrutura antes de planejar

Verifique antes de propor qualquer implementação:

- [ ] A feature muda o schema SwiftData? → adicionar `MigrationStage` no `VersionedSchema`
- [ ] A feature muda `IPCProtocol.swift`? → ambos os targets (app + helper) precisam ser atualizados
- [ ] A feature adiciona entitlement? → verificar se é compatível com notarização (evitar `temporary-exception.*`)
- [ ] A feature cria nova instância de `LocalProcessTerminalView`? → garantir `DispatchQueue` separada
- [ ] A feature executa processo filho? → filtrar env vars (allowlist: PATH, HOME, TERM)
- [ ] A feature lê input de hook? → validar via allowlist antes de processar

## Fase C — Worktree

```bash
# Convenção de branch: feature/<nome-kebab-case>
BRANCH="feature/<nome>"
WORKTREE_PATH=".claude/worktrees/<nome>"

git worktree add -b "$BRANCH" "$WORKTREE_PATH" HEAD
cd "$WORKTREE_PATH"
```

> Nota: o `.xcodeproj` fica no worktree mas abre no mesmo Xcode. Fechar e reabrir o projeto
> após criar o worktree se estiver com Xcode aberto.

## Fase D — Plano

Com o contexto lido e o checklist verificado, gere o plano no modo `/plan`.
Inclua explicitamente: arquivos a modificar, targets afetados, se há mudança de schema.
```

---

## `.claude/commands/ship-feature.md` — override local

```markdown
# /ship-feature

Entrega uma feature do claude-terminal: build, tests, PR.

## Pré-condições

- Worktree ativo em `.claude/worktrees/<nome>`
- Todos os arquivos commitados no branch da feature

## Passo 1 — Build e testes

```bash
# Build de todos os targets
xcodebuild build \
  -project ClaudeTerminal.xcodeproj \
  -scheme ClaudeTerminal \
  -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Testes unitários
xcodebuild test \
  -project ClaudeTerminal.xcodeproj \
  -scheme ClaudeTerminalTests \
  -destination "platform=macOS"
```

Se qualquer um falhar: parar, reportar, não criar PR.

## Passo 2 — Verificações manuais

- [ ] Schema SwiftData mudou? → `VersionedSchema` foi atualizado?
- [ ] `IPCProtocol.swift` mudou? → app E helper compilam com a mesma versão?
- [ ] Entitlements mudaram? → `app.entitlements` e `helper.entitlements` estão corretos?
- [ ] Novo código executa processo filho? → env vars filtrados?

## Passo 3 — PR

```bash
cd .claude/worktrees/<nome>
git push origin feature/<nome>
gh pr create \
  --title "<título conciso em inglês>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet point do que muda>
- <impacto nos targets afetados>

## Test plan
- [ ] `xcodebuild build` passa sem warnings novos
- [ ] `xcodebuild test` passa
- [ ] Testado manualmente: <descrever o fluxo testado>

## Schema changes
<"None" ou descrever a migration stage adicionada>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## Critério de "done"

- Build passa sem erros em todos os targets
- Testes passam (ou suite vazia — aceitável no v1)
- CI verde no PR
- PR criado com descrição adequada
```

---

## `.claude/commands/close-feature.md` — override local

```markdown
# /close-feature

Fecha uma feature após PR merged: cleanup do worktree e atualiza LEARNINGS.md.

## Passo 1 — Verificar que PR foi merged

```bash
gh pr view feature/<nome> --json state --jq '.state'
# Deve retornar "MERGED"
```

## Passo 2 — Cleanup do worktree

```bash
WORKTREE_PATH=".claude/worktrees/<nome>"
BRANCH="feature/<nome>"

# Remover worktree
git worktree remove "$WORKTREE_PATH" --force

# Deletar branch local
git branch -d "$BRANCH"

# Atualizar main
git checkout main
git pull origin main
```

## Passo 3 — LEARNINGS.md

Adicionar entry em `LEARNINGS.md` com:
- O que foi aprendido sobre o stack (SwiftData gotchas, IPC, etc.)
- O que funcionou bem
- O que evitar na próxima feature
- Tempo estimado vs. real (se relevante)

```bash
# Verificar que LEARNINGS.md foi atualizado
git diff HEAD LEARNINGS.md
```

## Passo 4 — Commit de cleanup (se necessário)

Se o LEARNINGS.md foi atualizado localmente (não no PR):
```bash
git add LEARNINGS.md
git commit -m "docs: add learnings from feature/<nome>"
git push origin main
```
```

---

## GitHub Actions — `release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write

jobs:
  build-and-release:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.3.app

      - name: Import Certificate
        run: |
          echo "${{ secrets.CERTIFICATE_P12_BASE64 }}" | base64 --decode > cert.p12
          security create-keychain -p "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain
          security import cert.p12 \
            -k build.keychain \
            -P "${{ secrets.CERTIFICATE_PASSWORD }}" \
            -T /usr/bin/codesign
          security set-key-partition-list \
            -S apple-tool:,apple: \
            -s -k "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain

      - name: Build Archive
        run: |
          xcodebuild archive \
            -project ClaudeTerminal.xcodeproj \
            -scheme ClaudeTerminal \
            -destination "generic/platform=macOS" \
            -archivePath "$RUNNER_TEMP/ClaudeTerminal.xcarchive" \
            CODE_SIGN_STYLE=Manual \
            CODE_SIGN_IDENTITY="Developer ID Application"

      - name: Export .app (bottom-up signing)
        run: |
          # Sign helper first, then app (critical order)
          ARCHIVE="$RUNNER_TEMP/ClaudeTerminal.xcarchive"
          APP="$RUNNER_TEMP/ClaudeTerminal.app"

          xcodebuild -exportArchive \
            -archivePath "$ARCHIVE" \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath "$RUNNER_TEMP/export"

          cp -R "$RUNNER_TEMP/export/ClaudeTerminal.app" "$APP"

          # Verify
          codesign --verify --deep --strict --verbose=2 "$APP"

      - name: Create and Sign DMG
        run: |
          APP="$RUNNER_TEMP/ClaudeTerminal.app"
          DMG="$RUNNER_TEMP/ClaudeTerminal-${{ github.ref_name }}.dmg"

          hdiutil create \
            -volname "Claude Terminal" \
            -srcfolder "$APP" \
            -ov -format UDZO "$DMG"

          codesign \
            --sign "Developer ID Application: ${{ secrets.APPLE_ID }} (${{ secrets.TEAM_ID }})" \
            "$DMG"

      - name: Notarize
        run: |
          DMG="$RUNNER_TEMP/ClaudeTerminal-${{ github.ref_name }}.dmg"

          xcrun notarytool submit "$DMG" \
            --apple-id "${{ secrets.APPLE_ID }}" \
            --password "${{ secrets.NOTARIZATION_PASSWORD }}" \
            --team-id "${{ secrets.TEAM_ID }}" \
            --wait

          xcrun stapler staple "$DMG"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: ${{ runner.temp }}/ClaudeTerminal-${{ github.ref_name }}.dmg
          generate_release_notes: true
```

---

## GitHub Actions — `.github/workflows/ci.yml` (override)

O `ci.yml` do template usa comandos genéricos que não funcionam para Swift/Xcode.
Override completo para usar `swift build` no bootstrap (funciona sem Xcode GUI):

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.3.app

      - name: Resolve dependencies
        run: swift package resolve

      - name: Build (all targets)
        run: swift build --configuration debug

      - name: Test
        run: swift test --configuration debug
```

> **Nota:** este CI usa `swift build` para o bootstrap. Após o usuário criar o `.xcodeproj`
> e configurar os targets de distribuição, atualizar para `xcodebuild build + test`.

---

## Dependências iniciais (Package.swift)

Criar `Package.swift` na raiz do projeto para permitir `swift build` no CI
sem depender do Xcode GUI:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeTerminal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClaudeTerminal", targets: ["ClaudeTerminal"]),
        .executable(name: "ClaudeTerminalHelper", targets: ["ClaudeTerminalHelper"]),
        .library(name: "Shared", targets: ["Shared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.3.0"),
        .package(url: "https://github.com/trilemma-dev/SecureXPC", from: "0.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeTerminal",
            dependencies: [
                "Shared",
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "SecureXPC", package: "SecureXPC"),
            ],
            path: "ClaudeTerminal",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ]
        ),
        .executableTarget(
            name: "ClaudeTerminalHelper",
            dependencies: [
                "Shared",
                .product(name: "SecureXPC", package: "SecureXPC"),
            ],
            path: "ClaudeTerminalHelper",
            swiftSettings: [
                .defaultIsolation(MainActor.self),
            ]
        ),
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "SecureXPC", package: "SecureXPC"),
            ],
            path: "Shared"
        ),
        .testTarget(
            name: "ClaudeTerminalTests",
            dependencies: ["ClaudeTerminal"],
            path: "ClaudeTerminalTests"
        ),
    ]
)
```

> **Nota:** o `Package.swift` permite `swift build` para CI. O `.xcodeproj` é criado
> separadamente via Xcode GUI para distribuição com entitlements, Info.plist e signing.

**Targets e suas dependências:**
- `ClaudeTerminal` (executable): SwiftTerm, SecureXPC, Shared
- `ClaudeTerminalHelper` (executable): SecureXPC, Shared
- `Shared` (library): SecureXPC
- `ClaudeTerminalTests` (test): ClaudeTerminal

---

## ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
    <key>teamID</key>
    <string>$(TEAM_ID)</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
```

---

## app.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime obrigatório para notarização -->
    <!-- NÃO adicionar: cs.disable-library-validation, cs.allow-unsigned-executable-memory -->
    <!-- NÃO adicionar: app-sandbox (incompatível com PTY e LocalProcessTerminalView) -->
</dict>
</plist>
```

---

## helper.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- PTY via POSIX não requer entitlement especial fora da sandbox -->
    <!-- Helper roda sem sandbox — sem com.apple.security.app-sandbox -->
</dict>
</plist>
```

---

## Critério de "bootstrap completo"

O projeto está pronto para receber features quando:

- [ ] `swift build --configuration debug` passa sem erros (todos os targets)
- [ ] `swift test --configuration debug` passa (suite vazia é aceitável)
- [ ] `Package.resolved` existe (dependências SPM resolvidas: SwiftTerm + SecureXPC)
- [ ] CI verde no primeiro PR de teste
- [ ] `bootstrap.yml` aplicou branch protection em main
- [ ] `app.entitlements` e `helper.entitlements` presentes e corretos
- [ ] `ExportOptions.plist` presente

> O `.xcodeproj` para distribuição é criado pelo usuário via Xcode GUI após o bootstrap —
> não é critério de completude da Fase 3.

---

## Sequência de execução da Fase 3

1. Confirmar visibilidade: **público** (open source, Apache 2.0 — alinhado ao brief)
2. `gh repo create claude-terminal --template rmolines/claude-kickstart --public --description "Mission Control for Claude Code agents — macOS native app"`
3. `git clone https://github.com/rmolines/claude-terminal.git && cd claude-terminal`
4. Criar `Package.swift` na raiz com conteúdo acima
5. Criar estrutura de pastas: `ClaudeTerminal/`, `ClaudeTerminalHelper/`, `Shared/`, `ClaudeTerminalTests/`
6. Criar arquivos-esqueleto Swift (stubs mínimos que compilam)
7. Criar `app.entitlements` e `helper.entitlements` com conteúdo acima
8. Criar `ExportOptions.plist` com conteúdo acima
9. Preencher `CLAUDE.md` com conteúdo da seção "CLAUDE.md do projeto" acima
10. Criar `.claude/commands/start-feature.md` com override acima
11. Criar `.claude/commands/ship-feature.md` com override acima
12. Criar `.claude/commands/close-feature.md` com override acima
13. Criar `.github/workflows/release.yml` com conteúdo acima
14. **Override** `.github/workflows/ci.yml` com conteúdo da seção acima (substitui ci.yml genérico do template)
15. Atualizar `.github/CODEOWNERS` com `@rmolines`
16. `swift package resolve` — verifica dependências
17. `swift build --configuration debug` — verifica compilação local antes do commit
18. `git add . && git commit -m "..."`
19. `git push origin main`
20. Aguardar CI verde
21. Verificar que `bootstrap.yml` aplicou branch protection em main
22. Validar checklist de "bootstrap completo"
23. Adicionar secrets no GitHub: `CERTIFICATE_P12_BASE64`, `CERTIFICATE_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_ID`, `NOTARIZATION_PASSWORD`, `TEAM_ID`

> **Passo 4 — Xcode project (pós-bootstrap):** após a Fase 3, o usuário cria o `.xcodeproj`
> via `File → New → Project → macOS → App` no Xcode, adiciona os targets e dependências SPM.
> O `Package.swift` serve para CI; o `.xcodeproj` serve para distribuição.

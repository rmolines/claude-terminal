# Plan: skills-navigator

## Problema

Usuário tem 15+ skills CLI composáveis mas não sabe qual usar no momento atual, como
combiná-las ou quais argumentos usar. A informação existe em workflow.md mas no lugar errado.
Solução: aba "Skills" no Claude Terminal que lê o estado atual (branch, worktrees, agentes ativos)
e apresenta as 1-3 transições válidas por agente, com comandos copiáveis.

## Arquivos a modificar / criar

### Novos (criar do zero)

- `ClaudeTerminal/Services/GitStateService.swift` — actor que executa git queries async
- `ClaudeTerminal/Features/Skills/WorkflowPhase.swift` — enum de fases + SkillDefinition static data
- `ClaudeTerminal/Features/Skills/AgentWorkflowCard.swift` — card por agente com estado + próximos passos
- `ClaudeTerminal/Features/Skills/SkillsNavigatorView.swift` — view principal da aba Skills

### Modificar

- `ClaudeTerminal/Features/Terminal/MainView.swift` — adicionar TabView com 2 tabs: Terminal + Skills

## Passos de execução

### Passo 1 — `WorkflowPhase.swift`

Criar `ClaudeTerminal/Features/Skills/WorkflowPhase.swift`:

```swift
import Foundation

/// Fase atual no workflow de skills, inferida a partir da branch e cwd.
enum WorkflowPhase: String {
    case strategic          // main branch — ideia → milestone
    case featureActive      // feature/xxx ou worktree ativo
    case readyToShip        // tem commits não publicados (heurística)
    case unknown            // não foi possível determinar

    /// Infere a fase a partir do nome da branch.
    static func infer(branch: String, cwd: String) -> WorkflowPhase {
        if branch.isEmpty || branch == "—" { return .unknown }
        if branch == "main" || branch == "master" { return .strategic }
        if branch.hasPrefix("feature/") || cwd.contains(".claude/worktrees/") {
            return .featureActive
        }
        if branch.hasPrefix("fix/") || branch.hasPrefix("chore/") {
            return .featureActive
        }
        return .unknown
    }
}

/// Definição estática de uma skill — nome, descrição curta, flags disponíveis, fase ideal.
struct SkillDefinition: Identifiable {
    let id: String        // ex: "/start-feature"
    let icon: String      // SF Symbol name
    let description: String
    let flags: [(flag: String, description: String)]   // argumentos opcionais
    let nextSkills: [String]   // skills que normalmente vêm depois
    let phases: [WorkflowPhase]   // em quais fases esta skill é válida
}

extension SkillDefinition {
    /// Todas as skills do sistema, em ordem de fluxo.
    static let all: [SkillDefinition] = [
        SkillDefinition(
            id: "/explore",
            icon: "sparkle.magnifyingglass",
            description: "Exploração profunda de um problema ou ideia",
            flags: [("--fast", "Scan rápido, 2-3 buscas"), ("--novel", "Raciocínio de primeira ordem, sem web search")],
            nextSkills: ["/start-project", "/start-feature --deep"],
            phases: [.strategic, .unknown]
        ),
        SkillDefinition(
            id: "/start-project",
            icon: "folder.badge.plus",
            description: "Cria repositório do zero a partir de um brief aprovado",
            flags: [],
            nextSkills: ["/plan-roadmap"],
            phases: [.strategic]
        ),
        SkillDefinition(
            id: "/plan-roadmap",
            icon: "map",
            description: "Define milestones e features no roadmap",
            flags: [],
            nextSkills: ["/start-milestone"],
            phases: [.strategic]
        ),
        SkillDefinition(
            id: "/start-milestone",
            icon: "flag",
            description: "Começa um milestone — gera sprint.md com features",
            flags: [],
            nextSkills: ["/start-feature"],
            phases: [.strategic]
        ),
        SkillDefinition(
            id: "/start-feature",
            icon: "plus.square",
            description: "Começa implementação de uma feature",
            flags: [
                ("--deep", "Pesquisa técnica completa antes de implementar"),
                ("--discover", "Explora o problema antes do bet, sem criar worktree")
            ],
            nextSkills: ["/validate", "/ship-feature"],
            phases: [.strategic, .featureActive]
        ),
        SkillDefinition(
            id: "/validate",
            icon: "checkmark.shield",
            description: "Verifica alinhamento do código com o plano antes do PR",
            flags: [],
            nextSkills: ["/ship-feature"],
            phases: [.featureActive, .readyToShip]
        ),
        SkillDefinition(
            id: "/ship-feature",
            icon: "paperplane",
            description: "Abre PR no GitHub após testes manuais ok",
            flags: [],
            nextSkills: ["/close-feature"],
            phases: [.featureActive, .readyToShip]
        ),
        SkillDefinition(
            id: "/close-feature",
            icon: "archivebox",
            description: "Limpa worktree e atualiza docs após PR merged",
            flags: [],
            nextSkills: ["/project-compass"],
            phases: [.featureActive, .readyToShip]
        ),
        SkillDefinition(
            id: "/debug",
            icon: "ant",
            description: "Investiga erro sem modificar nada — relatório de causa raiz",
            flags: [],
            nextSkills: ["/fix"],
            phases: [.strategic, .featureActive, .readyToShip, .unknown]
        ),
        SkillDefinition(
            id: "/project-compass",
            icon: "location.north",
            description: "\"Onde estou? O que fazer agora?\" — lê git + backlog + sprint.md",
            flags: [],
            nextSkills: [],
            phases: [.strategic, .featureActive, .readyToShip, .unknown]
        ),
        SkillDefinition(
            id: "/handover",
            icon: "person.2.wave.2",
            description: "Passa contexto para outro agente — resumo da sessão atual",
            flags: [],
            nextSkills: [],
            phases: [.featureActive, .readyToShip]
        ),
        SkillDefinition(
            id: "/design-review",
            icon: "paintbrush",
            description: "Gate de design antes de abrir PR com mudanças de UI",
            flags: [("--audit", "Diagnóstico completo do app"), ("--holistic", "Auditoria sistêmica por milestone")],
            nextSkills: ["/ship-feature"],
            phases: [.featureActive, .readyToShip]
        ),
    ]

    /// Skills válidas para uma fase específica, em ordem de prioridade.
    static func skills(for phase: WorkflowPhase) -> [SkillDefinition] {
        all.filter { $0.phases.contains(phase) }
    }

    /// Próximos passos recomendados para uma fase (subset de skills(for:)).
    static func nextSteps(for phase: WorkflowPhase) -> [SkillDefinition] {
        switch phase {
        case .strategic:
            return all.filter { ["/start-feature", "/plan-roadmap", "/start-milestone", "/explore"].contains($0.id) }
        case .featureActive:
            return all.filter { ["/validate", "/ship-feature", "/debug"].contains($0.id) }
        case .readyToShip:
            return all.filter { ["/ship-feature", "/close-feature"].contains($0.id) }
        case .unknown:
            return all.filter { ["/project-compass", "/explore"].contains($0.id) }
        }
    }
}
```

### Passo 2 — `GitStateService.swift`

Criar `ClaudeTerminal/Services/GitStateService.swift`:

```swift
import Foundation

/// Executa queries de git de forma assíncrona sem bloquear atores.
/// Todos os métodos são nonisolated para poder ser chamados de qualquer contexto.
actor GitStateService {
    static let shared = GitStateService()
    private init() {}

    /// Retorna a branch atual no diretório dado. Retorna "—" em caso de erro.
    func currentBranch(in directory: String) async -> String {
        guard FileManager.default.fileExists(atPath: directory) else { return "—" }
        let output = try? await runGit(args: ["branch", "--show-current"], cwd: directory)
        return output?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "—"
    }

    /// Extrai o nome do worktree do caminho (ex: ".claude/worktrees/my-feature" → "my-feature").
    nonisolated func worktreeName(from cwd: String) -> String? {
        guard let range = cwd.range(of: ".claude/worktrees/") else { return nil }
        let after = String(cwd[range.upperBound...])
        return after.components(separatedBy: "/").first.flatMap { $0.nilIfEmpty }
    }

    // MARK: - Private

    private func runGit(args: [String], cwd: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            process.environment = ["PATH": "/usr/bin:/usr/local/bin:/opt/homebrew/bin", "HOME": NSHomeDirectory()]

            let outPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = Pipe()  // discard stderr

            process.terminationHandler = { @Sendable p in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                if p.terminationStatus == 0 {
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } else {
                    continuation.resume(throwing: GitError.nonZeroExit(p.terminationStatus))
                }
            }

            do { try process.run() }
            catch { continuation.resume(throwing: error) }
        }
    }
}

enum GitError: Error {
    case nonZeroExit(Int32)
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
```

### Passo 3 — `AgentWorkflowCard.swift`

Criar `ClaudeTerminal/Features/Skills/AgentWorkflowCard.swift`:

Card SwiftUI por agente. Recebe `AgentSession` + `branch: String` (carregado externamente).
Mostra:
- Header: sessionID abreviado, status badge, branch
- Body: "Próximos passos" — máximo 3 skills, cada uma com botão "Copy"
- Disclosure: "Todas as skills desta fase" — lista compacta

### Passo 4 — `SkillsNavigatorView.swift`

Criar `ClaudeTerminal/Features/Skills/SkillsNavigatorView.swift`:

View principal da aba Skills.
- Observa `SessionStore.shared.sessions`
- Mantém `@State private var branchBySession: [String: String] = [:]`
- `.task {}` que, a cada 15s, chama `GitStateService.shared.currentBranch(in: session.cwd)` para cada sessão ativa e atualiza o dict
- Se `sessions` está vazio: empty state view
- Caso contrário: `ScrollView` com `VStack` de `AgentWorkflowCard` por sessão

### Passo 5 — Modificar `MainView.swift`

Envolver o VStack atual em um `TabView` com 2 tabs:
- Tab "Terminal": conteúdo existente (header + Divider + terminal)
- Tab "Skills": `SkillsNavigatorView()`

```swift
enum AppTab: String {
    case terminal, skills
}

@State private var selectedTab: AppTab = .terminal

var body: some View {
    TabView(selection: $selectedTab) {
        // Tab 1: terminal (conteúdo existente)
        terminalTab
            .tabItem { Label("Terminal", systemImage: "terminal") }
            .tag(AppTab.terminal)

        // Tab 2: skills navigator
        SkillsNavigatorView()
            .tabItem { Label("Skills", systemImage: "bolt.horizontal") }
            .tag(AppTab.skills)
    }
    .frame(minWidth: 700, minHeight: 400)
}
```

O conteúdo atual de `body` (VStack + frame) migra para `var terminalTab: some View`.

## Checklist de infraestrutura

- [ ] Novo Secret: não
- [ ] Script de setup: não
- [ ] CI/CD: não muda
- [ ] Config principal: não muda
- [ ] Novas dependências SPM: não (Foundation.Process nativo)
- [ ] Novo diretório: `ClaudeTerminal/Features/Skills/` (criar)

## Rollback

```bash
git checkout ClaudeTerminal/Features/Terminal/MainView.swift
git rm -r ClaudeTerminal/Features/Skills/
git rm ClaudeTerminal/Services/GitStateService.swift
```

## Learnings aplicados

- `Foundation.Process.terminationHandler` → closure como `@Sendable` (Swift 6 Sendable warning)
- `TabView` sem `.sidebarAdaptable` é estável em macOS 14+ (evitar sidebarAdaptable — crash macOS 15.1)
- `nonisolated func` para helpers puros que não mutam estado do actor
- `.task {}` para polling — cancela automaticamente quando a view sai de cena
- `NSPasteboard.general` direto em view @MainActor — sem Task/await necessário

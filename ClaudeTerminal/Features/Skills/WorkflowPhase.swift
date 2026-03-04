import Foundation

/// Fase atual no workflow de skills, inferida a partir da branch e cwd.
enum WorkflowPhase: String {
    case strategic          // main branch — ideia → milestone
    case featureActive      // feature/xxx ou worktree ativo
    case readyToShip        // tem commits não publicados (heurística)
    case unknown            // não foi possível determinar

    /// Infere a fase a partir do nome da branch e do cwd.
    static func infer(branch: String, cwd: String) -> WorkflowPhase {
        // cwd is reliable even before the branch query resolves.
        if cwd.contains(".claude/worktrees/") { return .featureActive }
        if branch.isEmpty || branch == "—" { return .unknown }
        if branch == "main" || branch == "master" { return .strategic }
        if branch.hasPrefix("feature/") || branch.hasPrefix("fix/") || branch.hasPrefix("chore/") || branch.hasPrefix("worktree-") {
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
    let flags: [(flag: String, description: String)]
    let nextSkills: [String]
    let phases: [WorkflowPhase]
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

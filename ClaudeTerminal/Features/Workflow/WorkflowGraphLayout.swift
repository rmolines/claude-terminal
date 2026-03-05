import Foundation

// MARK: - SOURCE OF TRUTH
//
// Este arquivo é o único lugar onde topologia + layout + variantes do workflow de skills
// são declarados juntos. Para alterar o grafo:
//
//   Adicionar skill:   SkillDefinition.all em WorkflowPhase.swift + nó e arestas aqui
//   Remover skill:     idem (remover dos dois)
//   Mover no grafo:    só aqui (posições normalizadas)
//   Adicionar variante (--deep, --discover): arestas com isCanonical: false aqui

// MARK: - Structs

/// A node in the workflow graph. Position is normalized (0.0–1.0) relative to canvas size.
struct WorkflowNode: Identifiable {
    let id: String       // skill ID, e.g. "/start-feature"
    let icon: String     // SF Symbol name
    let label: String    // short display label (without leading /)
    let x: Double        // normalized x position (0.0 = left, 1.0 = right)
    let y: Double        // normalized y position (0.0 = top, 1.0 = bottom)
}

/// A directed edge between two nodes.
struct WorkflowEdge: Identifiable {
    let id: String
    let from: String   // source node ID
    let to: String     // destination node ID
    /// Canonical edges are the main workflow path. Non-canonical = variant paths (flags).
    let isCanonical: Bool

    init(from: String, to: String, isCanonical: Bool = true) {
        self.id = "\(from)→\(to)"
        self.from = from
        self.to = to
        self.isCanonical = isCanonical
    }
}

// MARK: - Layout

enum WorkflowGraphLayout {
    // MARK: Nodes
    //
    // Main flow: x=0.35, y from 0.05 to 0.93 in steps of ~0.11
    // Side nodes: x=0.75

    static let nodes: [WorkflowNode] = [
        // --- Main flow (canonical left column) ---
        WorkflowNode(id: "/explore",         icon: "sparkle.magnifyingglass", label: "explore",         x: 0.35, y: 0.05),
        WorkflowNode(id: "/start-project",   icon: "folder.badge.plus",       label: "start-project",   x: 0.35, y: 0.16),
        WorkflowNode(id: "/plan-roadmap",    icon: "map",                     label: "plan-roadmap",    x: 0.35, y: 0.27),
        WorkflowNode(id: "/start-milestone", icon: "flag",                    label: "start-milestone", x: 0.35, y: 0.38),
        WorkflowNode(id: "/start-feature",   icon: "plus.square",             label: "start-feature",   x: 0.35, y: 0.49),
        WorkflowNode(id: "/validate",        icon: "checkmark.shield",        label: "validate",        x: 0.35, y: 0.60),
        WorkflowNode(id: "/ship-feature",    icon: "paperplane",              label: "ship-feature",    x: 0.35, y: 0.71),
        WorkflowNode(id: "/close-feature",   icon: "archivebox",              label: "close-feature",   x: 0.35, y: 0.82),
        WorkflowNode(id: "/project-compass", icon: "location.north",          label: "project-compass", x: 0.35, y: 0.93),

        // --- Side nodes ---
        WorkflowNode(id: "/debug",           icon: "ant",                     label: "debug",           x: 0.75, y: 0.27),
        WorkflowNode(id: "/handover",        icon: "person.2.wave.2",         label: "handover",        x: 0.75, y: 0.44),
        WorkflowNode(id: "/design-review",   icon: "paintbrush",              label: "design-review",   x: 0.75, y: 0.655),
    ]

    // MARK: Edges

    static let edges: [WorkflowEdge] = [
        // Main flow
        WorkflowEdge(from: "/explore",         to: "/start-project"),
        WorkflowEdge(from: "/start-project",   to: "/plan-roadmap"),
        WorkflowEdge(from: "/plan-roadmap",    to: "/start-milestone"),
        WorkflowEdge(from: "/start-milestone", to: "/start-feature"),
        WorkflowEdge(from: "/start-feature",   to: "/validate"),
        WorkflowEdge(from: "/validate",        to: "/ship-feature"),
        WorkflowEdge(from: "/ship-feature",    to: "/close-feature"),
        WorkflowEdge(from: "/close-feature",   to: "/project-compass"),

        // Variant edges (non-canonical)
        WorkflowEdge(from: "/explore",       to: "/start-feature",  isCanonical: false),
        WorkflowEdge(from: "/validate",      to: "/design-review",  isCanonical: false),
        WorkflowEdge(from: "/design-review", to: "/ship-feature",   isCanonical: false),
        WorkflowEdge(from: "/debug",         to: "/validate",       isCanonical: false),
    ]

    // MARK: Helpers

    static func node(for id: String) -> WorkflowNode? {
        nodes.first { $0.id == id }
    }

    /// IDs of nodes that must be done before `nodeID` can be considered non-anomalous.
    static func prerequisites(of nodeID: String) -> [String] {
        edges.filter { $0.to == nodeID && $0.isCanonical }.map(\.from)
    }
}

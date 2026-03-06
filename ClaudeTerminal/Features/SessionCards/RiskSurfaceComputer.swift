/// Risk level for a pending HITL operation, used to triage approvals visually.
enum RiskLevel {
    case normal
    case elevated
    case critical
}

/// Computes risk level from tool name and detail string via conservative pattern matching.
/// Isolated here so calibration (false positive tuning) is independent from UI code.
struct RiskSurfaceComputer {
    private static let criticalPatterns: [String] = [
        "rm -rf", "rm -r /", "rm -f /",
        "git push --force", "git push -f",
        "DROP TABLE", "DROP DATABASE", "TRUNCATE TABLE",
        "format ", "mkfs", "dd if=",
        "> /dev/", "shred "
    ]

    private static let elevatedPatterns: [String] = [
        "git push", "git reset",
        "DELETE FROM", "UPDATE ", "ALTER TABLE",
        "mv /", "chmod -R", "chown -R",
        "sudo ", "su -",
        "curl ", "wget ", "pip install", "npm install"
    ]

    static func compute(toolName: String?, detail: String?) -> RiskLevel {
        let haystack = [toolName, detail].compactMap { $0 }.joined(separator: " ").lowercased()
        for pattern in criticalPatterns where haystack.contains(pattern.lowercased()) {
            return .critical
        }
        for pattern in elevatedPatterns where haystack.contains(pattern.lowercased()) {
            return .elevated
        }
        return .normal
    }
}

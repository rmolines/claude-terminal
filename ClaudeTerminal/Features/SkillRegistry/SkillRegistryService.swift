import Foundation

func loadSkills(projectCwds: [String]) async -> [SkillEntry] {
    var entries: [SkillEntry] = []

    let skillsDir = ("~/.claude/skills" as NSString).expandingTildeInPath
    let globalCommandsDir = ("~/.claude/commands" as NSString).expandingTildeInPath

    entries += scan(directory: skillsDir, kind: .autoTrigger)
    entries += scan(directory: globalCommandsDir, kind: .globalCommand)

    let fm = FileManager.default
    for cwd in projectCwds {
        let projectCommandsDir = (cwd as NSString).appendingPathComponent(".claude/commands")
        if fm.fileExists(atPath: projectCommandsDir) {
            entries += scan(directory: projectCommandsDir, kind: .projectCommand)
        }
    }

    return entries
}

private func scan(directory: String, kind: SkillKind) -> [SkillEntry] {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

    return files
        .filter { $0.hasSuffix(".md") }
        .compactMap { filename -> SkillEntry? in
            let filePath = (directory as NSString).appendingPathComponent(filename)
            guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }
            let (name, description) = parseNameAndDescription(filename: filename, content: content)
            return SkillEntry(id: filePath, name: name, description: description, filePath: filePath, kind: kind)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

private func parseNameAndDescription(filename: String, content: String) -> (name: String, description: String) {
    let lines = content.components(separatedBy: "\n")

    // Try frontmatter block: file starts with ---
    if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
        var name: String?
        var description: String?
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            if trimmed.hasPrefix("name:") {
                name = trimmed.dropFirst("name:".count).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("description:") {
                description = trimmed.dropFirst("description:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        let resolvedName = name ?? humanize(filename: filename)
        let resolvedDesc = description ?? firstMeaningfulLine(lines: lines)
        return (resolvedName, resolvedDesc)
    }

    // Fallback: use humanized filename + first non-heading non-empty line
    return (humanize(filename: filename), firstMeaningfulLine(lines: lines))
}

private func humanize(filename: String) -> String {
    let base = (filename as NSString).deletingPathExtension
    return base
        .components(separatedBy: CharacterSet(charactersIn: "-_"))
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        .joined(separator: " ")
}

private func firstMeaningfulLine(lines: [String]) -> String {
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        if trimmed.hasPrefix("#") {
            // Strip leading # and whitespace — use heading text as description
            let stripped = trimmed.drop(while: { $0 == "#" || $0 == " " })
            let text = String(stripped).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { return text }
            continue
        }
        return trimmed
    }
    return ""
}

import Foundation

/// Curated topic list — mirrors `backend/app/db/topics.py` KNOWN_TOPICS.
enum KnownTopics {
    static let defaultTopic = "general"

    static let all: [String] = [
        defaultTopic,
        "politics",
        "technology",
        "science",
        "entertainment",
        "sports",
        "business",
        "health",
        "education",
        "environment",
    ]

    static func displayName(for topic: String) -> String {
        topic.prefix(1).uppercased() + topic.dropFirst()
    }

    /// Returns the canonical known topic for `value`, or `nil` if it is not in `all`.
    static func resolve(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return all.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    /// Topics whose names contain `query` (case-insensitive), excluding already-selected ones.
    static func matching(_ query: String, excluding: [String] = []) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let excluded = Set(excluding.map { $0.lowercased() })
        let available = all.filter { !excluded.contains($0.lowercased()) }

        guard !trimmed.isEmpty else { return available }

        return available.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}

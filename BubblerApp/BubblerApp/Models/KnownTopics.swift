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
}

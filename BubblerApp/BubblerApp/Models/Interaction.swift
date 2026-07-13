import Foundation

/// Mirrors backend `Interaction` from GET /user/me.
struct Interaction: Codable, Identifiable {
    let id: String
    let userId: String
    let postId: String
    let type: GraphInteractionType
    let createdAt: Date
    let topic: String
    let viewTime: Double
    let liked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case type
        case createdAt = "created_at"
        case topic
        case viewTime = "view_time"
        case liked
    }

    /// Short copy for the profile Bubble Trail row.
    var trailSummary: String {
        let topicLabel: String
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            topicLabel = "a post"
        } else {
            topicLabel = "a \(KnownTopics.displayName(for: trimmed)) post"
        }

        switch type {
        case .like:
            return "Liked \(topicLabel)"
        case .skip:
            return "Skipped \(topicLabel)"
        case .explore:
            return "Explored \(topicLabel)"
        }
    }
}

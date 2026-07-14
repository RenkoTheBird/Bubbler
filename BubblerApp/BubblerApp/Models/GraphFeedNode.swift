import Foundation
import Combine

struct GraphFeedNode: Identifiable {
    let post: Post
    let isPreferredTopic: Bool
    let isBlacklistedTopic: Bool

    var id: String { post.id }
    var content: String { post.content }
    var userId: Int { post.userId }
    var createdAt: Date { post.createdAt }

    var topicName: String? {
        guard let topic = post.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
              !topic.isEmpty else {
            return nil
        }
        return topic
    }
}

struct GraphSessionFeed: Codable {
    let posts: [Post]
    let seedStrategy: String
    let diversify: Bool

    enum CodingKeys: String, CodingKey {
        case posts
        case seedStrategy = "seed_strategy"
        case diversify
    }

    var statusLabel: String {
        switch seedStrategy {
        case "diversify", "diversify_fallback":
            return "Exploring across topics"
        case "soft_prior", "soft_prior_fallback":
            return "Seeded from recent interests"
        case "random":
            return "Random topic mix"
        default:
            return "Graph session ready"
        }
    }
}

enum GraphInteractionType: String, Codable {
    case like
    case skip
    case explore
}

struct GraphInteractionPayload: Codable {
    let postId: String
    let type: GraphInteractionType
    let viewTime: Double

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case type
        case viewTime = "view_time"
    }
}

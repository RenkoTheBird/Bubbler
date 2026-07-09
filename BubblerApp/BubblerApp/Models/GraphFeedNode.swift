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

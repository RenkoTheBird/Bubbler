import Foundation

/// A user the current account has blocked (`GET /user/me/blocks`).
struct BlockedUser: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    let blockedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case blockedAt = "blocked_at"
    }
}

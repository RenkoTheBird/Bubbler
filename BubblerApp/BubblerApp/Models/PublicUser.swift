import Foundation

/// Public profile returned by GET /user/{username}/profile (no email).
struct PublicUser: Decodable, Identifiable {
    let id: Int
    let username: String
    let createdAt: Date
    let isBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
        case isBlocked = "is_blocked"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isBlocked = try container.decodeIfPresent(Bool.self, forKey: .isBlocked) ?? false
    }
}

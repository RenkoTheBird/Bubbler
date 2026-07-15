import Foundation

/// Public profile returned by GET /user/{username}/profile (no email).
struct PublicUser: Codable, Identifiable {
    let id: Int
    let username: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
    }
}

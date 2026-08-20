import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let role: String
    let createdAt: Date

    var isStaff: Bool {
        role == "staff"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case role
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "user"
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

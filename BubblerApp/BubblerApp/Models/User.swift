import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let created_at: Date

    enum CodingKeys: String, CodingKey {
        case id  
        case username
        case email 
        case created_at
    }
}


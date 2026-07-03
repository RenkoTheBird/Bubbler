import Foundation 

// Codable: decode FastAPI JSON
// Identifiable: SwiftUI list compatibility
struct Post: Codable, Identifiable {
    let id: String
    let userId: Int
    let content: String
    let createdAt: Date
    let topic: String?

    // Optional on frontend but here for compatibility
    let embedding: [Double]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case embedding
        case topic
    }
}

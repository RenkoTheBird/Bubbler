//
//  Post.swift
//  BubblerApp
//

import Foundation

struct Post: Decodable, Identifiable, Sendable {
    let id: String
    let userId: Int?
    let content: String
    let createdAt: Date?
    let topic: String?
    let embedding: [Double]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case topic
        case embedding
    }
}

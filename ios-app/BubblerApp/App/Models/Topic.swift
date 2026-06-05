import Foundation 

// Codable: decode FastAPI JSON
// Identifiable: SwiftUI list compatibility
struct Topic: Codable, Identifiable {
    let id: UUID
    let name: String
    let parent_topic_id: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case parent_topic_id
    }
}


///
/// from dataclasses import dataclass

/// @dataclass
/// class Topic:
///    id: str
///    name: str
///    parent_topic_id: int
/// 
/// 

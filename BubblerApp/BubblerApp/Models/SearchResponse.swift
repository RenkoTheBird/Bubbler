import Foundation

/// Hybrid search payload from `GET /search?q=...`.
struct SearchResponse: Codable {
    let query: String
    let exactMatches: [Post]
    let related: [Post]

    enum CodingKeys: String, CodingKey {
        case query
        case exactMatches = "exact_matches"
        case related
    }

    var isEmpty: Bool {
        exactMatches.isEmpty && related.isEmpty
    }
}

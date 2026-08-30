import Combine
import Foundation

/// Per-post feed preference scale (-2...2). Zero means neutral (no stored preference).
enum FeedPreference: Int, CaseIterable, Codable {
    case muchLess = -2
    case less = -1
    case neutral = 0
    case more = 1
    case muchMore = 2

    var label: String {
        switch self {
        case .muchLess:
            return "Show a lot less like this"
        case .less:
            return "Show less like this"
        case .neutral:
            return "Neutral"
        case .more:
            return "Show more like this"
        case .muchMore:
            return "Show a lot more like this"
        }
    }

    var shortLabel: String {
        switch self {
        case .muchLess: return "Much less"
        case .less: return "Less"
        case .neutral: return "Neutral"
        case .more: return "More"
        case .muchMore: return "Much more"
        }
    }

    init(rawValueOrZero value: Int) {
        self = FeedPreference(rawValue: value) ?? .neutral
    }
}

struct FeedPreferenceEntry: Codable, Identifiable {
    var id: String { postId }
    let postId: String
    let feedPreference: Int

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case feedPreference = "feed_preference"
    }
}

struct FeedPreferenceUpdateBody: Codable {
    let feedPreference: Int

    enum CodingKeys: String, CodingKey {
        case feedPreference = "feed_preference"
    }
}

/// Shared feed-preference state so sliders stay consistent across Graph, Feed, and Search.
@MainActor
final class FeedPreferencesStore: ObservableObject {
    @Published private(set) var preferencesByPostID: [String: Int] = [:]

    func preference(for postID: String) -> FeedPreference {
        FeedPreference(rawValueOrZero: preferencesByPostID[postID] ?? 0)
    }

    func setPreference(_ value: FeedPreference, for postID: String) {
        if value == .neutral {
            preferencesByPostID.removeValue(forKey: postID)
        } else {
            preferencesByPostID[postID] = value.rawValue
        }
    }

    func refresh() async {
        do {
            let entries = try await APIClient.getFeedPreferences()
            preferencesByPostID = Dictionary(
                uniqueKeysWithValues: entries.map { ($0.postId, $0.feedPreference) }
            )
        } catch {
            // Keep the local map if preferences can't be loaded.
        }
    }

    func clear() {
        preferencesByPostID = [:]
    }
}

// Backward-compatible alias while call sites migrate.
typealias LikedPostsStore = FeedPreferencesStore

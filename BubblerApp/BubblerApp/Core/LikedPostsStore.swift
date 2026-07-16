import Combine
import Foundation

/// Shared liked-post IDs so hearts stay consistent across Graph, Feed, and Search.
@MainActor
final class LikedPostsStore: ObservableObject {
    @Published private(set) var likedPostIDs = Set<String>()

    func isLiked(_ postID: String) -> Bool {
        likedPostIDs.contains(postID)
    }

    func setLiked(_ postID: String, liked: Bool) {
        if liked {
            likedPostIDs.insert(postID)
        } else {
            likedPostIDs.remove(postID)
        }
    }

    func refresh() async {
        do {
            let ids = try await APIClient.getLikedPostIDs()
            likedPostIDs = Set(ids)
        } catch {
            // Keep the local set if likes can't be loaded.
        }
    }

    func clear() {
        likedPostIDs = []
    }
}

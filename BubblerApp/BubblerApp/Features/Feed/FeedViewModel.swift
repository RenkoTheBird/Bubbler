//
//  FeedViewModel.swift
//  BubblerApp
//

import Combine
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    /// `nil` means the mixed "All" feed; otherwise a KnownTopics value.
    @Published var selectedTopic: String? = nil
    @Published var posts: [Post] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    func selectTopic(_ topic: String?, using authSession: AuthSession) async {
        let normalized: String?
        if let topic {
            let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized = trimmed.isEmpty ? nil : trimmed.lowercased()
        } else {
            normalized = nil
        }

        guard selectedTopic != normalized || posts.isEmpty else { return }
        selectedTopic = normalized
        posts = []
        await loadFeed(using: authSession)
    }

    func loadFeed(using authSession: AuthSession) async {
        guard authSession.accessToken != nil else {
            posts = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await APIClient.getFeed(query: selectedTopic)
            posts = Self.prioritize(posts: fetched, topic: selectedTopic)
        } catch APIClientError.unauthorized {
            posts = []
            errorMessage = APIClientError.unauthorized.localizedDescription
            authSession.signOut()
        } catch {
            posts = []
            errorMessage = error.localizedDescription
        }
    }

    /// Keeps same-topic posts first while preserving relative order within each group.
    private static func prioritize(posts: [Post], topic: String?) -> [Post] {
        guard let topic else { return posts }

        return posts.enumerated()
            .sorted { lhs, rhs in
                let leftMatch = matchesTopic(lhs.element, topic: topic)
                let rightMatch = matchesTopic(rhs.element, topic: topic)
                if leftMatch != rightMatch {
                    return leftMatch && !rightMatch
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func matchesTopic(_ post: Post, topic: String) -> Bool {
        guard let postTopic = post.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
              !postTopic.isEmpty else {
            return false
        }
        return postTopic.caseInsensitiveCompare(topic) == .orderedSame
    }

    func removePost(id: String) {
        posts.removeAll { $0.id == id }
    }

    func updatePostContent(id: String, content: String) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        let existing = posts[index]
        posts[index] = Post(
            id: existing.id,
            userId: existing.userId,
            content: content,
            createdAt: existing.createdAt,
            topic: existing.topic,
            embedding: existing.embedding
        )
    }
}

//
//  ProfileViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var username: String?
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// `nil` loads the signed-in user's profile (`/user/me/...`).
    let targetUsername: String?

    private var hasLoaded = false

    init(username: String? = nil) {
        let trimmed = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.targetUsername = trimmed.isEmpty ? nil : trimmed
    }

    var isOwnProfile: Bool { targetUsername == nil }

    var displayUsername: String {
        if let username, !username.isEmpty {
            return "@\(username)"
        }
        return isLoading ? "Loading..." : "@…"
    }

    var profileSubtitle: String {
        isOwnProfile ? "Your bubble profile 🫧" : "Bubble node in your network"
    }

    var activeBubbleLabel: String {
        guard let topic = uniqueTopics(from: posts).first else {
            return isLoading ? "Loading bubbles…" : "No active bubble yet"
        }
        return "🫧 Active Bubble: \(KnownTopics.displayName(for: topic))"
    }

    var emptyPostsMessage: String {
        if isLoading {
            return isOwnProfile ? "Loading your posts…" : "Loading posts…"
        }
        return isOwnProfile
            ? "Posts you create will show up here."
            : "No posts yet."
    }

    func loadProfile(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorMessage = nil

        do {
            if let targetUsername {
                async let profileTask = APIClient.getUser(username: targetUsername)
                async let postsTask = APIClient.getUserPosts(username: targetUsername)

                let profile = try await profileTask
                let loadedPosts = try await postsTask

                username = profile.username
                posts = loadedPosts
            } else {
                async let profileTask = APIClient.getProfile()
                async let postsTask = APIClient.getMyPosts()

                let profile = try await profileTask
                let loadedPosts = try await postsTask

                username = profile.username
                posts = loadedPosts
            }
            hasLoaded = true
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = description.isEmpty
                ? (isOwnProfile
                    ? "We couldn't load your profile."
                    : "We couldn't load this profile.")
                : description
        }

        isLoading = false
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
            username: existing.username,
            content: content,
            createdAt: existing.createdAt,
            topic: existing.topic,
            embedding: existing.embedding
        )
    }

    /// Topics from the user's posts, most recently posted first, case-insensitive unique.
    private func uniqueTopics(from posts: [Post]) -> [String] {
        var seen = Set<String>()
        var topics: [String] = []

        for post in posts {
            guard let raw = post.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else {
                continue
            }
            let key = raw.lowercased()
            guard seen.insert(key).inserted else { continue }
            topics.append(raw)
        }

        return topics
    }
}

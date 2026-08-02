//
//  ProfileViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var userId: Int?
    @Published private(set) var username: String?
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isBlocked = false
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdatingBlock = false
    @Published var errorMessage: String?

    /// `nil` loads the signed-in user's profile (`/user/me/...`).
    let targetUsername: String?

    private var hasLoaded = false

    init(username: String? = nil) {
        let trimmed = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.targetUsername = trimmed.isEmpty ? nil : trimmed
    }

    var isOwnProfile: Bool { targetUsername == nil }

    func isOwnProfile(for authSession: AuthSession) -> Bool {
        if isOwnProfile { return true }
        guard let userId, let sessionUserId = authSession.userId else { return false }
        return userId == sessionUserId
    }

    var canManageBlock: Bool {
        !isOwnProfile && username != nil && !isLoading
    }

    var displayUsername: String {
        if let username, !username.isEmpty {
            return "@\(username)"
        }
        return isLoading ? "Loading..." : "@…"
    }

    var profileSubtitle: String {
        if isBlocked {
            return "You blocked this user"
        }
        return isOwnProfile ? "Your bubble profile 🫧" : "Bubble node in your network"
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

        // Keep existing posts visible while refreshing so tab switches don't flash empty.
        let showLoadingPlaceholder = posts.isEmpty
        if showLoadingPlaceholder {
            isLoading = true
        }
        errorMessage = nil

        do {
            if let targetUsername {
                async let profileTask = APIClient.getUser(username: targetUsername)
                async let postsTask = APIClient.getUserPosts(username: targetUsername)

                let profile = try await profileTask
                let loadedPosts = try await postsTask

                userId = profile.id
                username = profile.username
                isBlocked = profile.isBlocked
                posts = loadedPosts
            } else {
                async let profileTask = APIClient.getProfile()
                async let postsTask = APIClient.getMyPosts()

                let profile = try await profileTask
                let loadedPosts = try await postsTask

                userId = profile.id
                username = profile.username
                isBlocked = false
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

    /// Call after creating a post (or when returning to the Profile tab).
    func refreshPosts(using authSession: AuthSession) async {
        await loadProfile(using: authSession, force: true)
    }

    func blockUser(using authSession: AuthSession) async {
        guard let username, canManageBlock, !isUpdatingBlock else { return }

        isUpdatingBlock = true
        errorMessage = nil

        do {
            let profile = try await APIClient.blockUser(username: username)
            userId = profile.id
            self.username = profile.username
            isBlocked = profile.isBlocked
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = description.isEmpty
                ? "We couldn't block this user."
                : description
        }

        isUpdatingBlock = false
    }

    func unblockUser(using authSession: AuthSession) async {
        guard let username, canManageBlock, !isUpdatingBlock else { return }

        isUpdatingBlock = true
        errorMessage = nil

        do {
            let profile = try await APIClient.unblockUser(username: username)
            userId = profile.id
            self.username = profile.username
            isBlocked = profile.isBlocked
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = description.isEmpty
                ? "We couldn't unblock this user."
                : description
        }

        isUpdatingBlock = false
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

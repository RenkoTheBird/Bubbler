//
//  ProfileViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var username: String?
    @Published private(set) var postedTopics: [String] = []
    @Published private(set) var trailInteractions: [Interaction] = []
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
        guard let topic = postedTopics.first else {
            return isLoading ? "Loading bubbles…" : "No active bubble yet"
        }
        return "🫧 Active Bubble: \(KnownTopics.displayName(for: topic))"
    }

    var emptyBubblesMessage: String {
        if isLoading {
            return isOwnProfile ? "Loading your bubbles…" : "Loading bubbles…"
        }
        return isOwnProfile
            ? "Post about a topic to grow your bubbles."
            : "No bubbles yet."
    }

    var emptyTrailMessage: String {
        isLoading
            ? "Loading your bubble trail…"
            : "Your bubble trail will appear here once you start interacting with posts."
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
                let posts = try await postsTask

                username = profile.username
                postedTopics = Self.uniqueTopics(from: posts)
                trailInteractions = []
            } else {
                async let profileTask = APIClient.getProfile()
                async let postsTask = APIClient.getMyPosts()
                async let interactionsTask = APIClient.getMyInteractions()

                let profile = try await profileTask
                let posts = try await postsTask
                let interactions = try await interactionsTask

                username = profile.username
                postedTopics = Self.uniqueTopics(from: posts)
                trailInteractions = interactions
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

    /// Topics from the user's posts, most recently posted first, case-insensitive unique.
    private static func uniqueTopics(from posts: [Post]) -> [String] {
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

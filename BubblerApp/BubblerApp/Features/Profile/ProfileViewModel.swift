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

    private var hasLoaded = false

    var displayUsername: String {
        if let username, !username.isEmpty {
            return "@\(username)"
        }
        return isLoading ? "Loading..." : "@…"
    }

    var activeBubbleLabel: String {
        guard let topic = postedTopics.first else {
            return isLoading ? "Loading bubbles…" : "No active bubble yet"
        }
        return "🫧 Active Bubble: \(KnownTopics.displayName(for: topic))"
    }

    func loadProfile(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorMessage = nil

        do {
            async let profileTask = APIClient.getProfile()
            async let postsTask = APIClient.getMyPosts()
            async let interactionsTask = APIClient.getMyInteractions()

            let profile = try await profileTask
            let posts = try await postsTask
            let interactions = try await interactionsTask

            username = profile.username
            postedTopics = Self.uniqueTopics(from: posts)
            trailInteractions = interactions
            hasLoaded = true
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = description.isEmpty
                ? "We couldn't load your profile."
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

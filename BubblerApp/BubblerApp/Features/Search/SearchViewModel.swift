//
//  SearchViewModel.swift
//  BubblerApp
//

import Combine
import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var posts: [Post] = []
    @Published var recentSearches: [String] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published private(set) var hasSearched = false

    private static let maxRecentSearches = 5
    private var loadedUserId: Int?

    func loadRecentSearches(for userId: Int?) {
        guard let userId else {
            recentSearches = []
            loadedUserId = nil
            return
        }

        guard loadedUserId != userId else { return }
        loadedUserId = userId
        recentSearches = Self.loadStoredSearches(for: userId)
    }

    func search(using authSession: AuthSession, query: String? = nil) async {
        let trimmed = (query ?? searchText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Enter a search to find bubbles."
            return
        }

        guard authSession.accessToken != nil else {
            posts = []
            errorMessage = nil
            return
        }

        searchText = trimmed
        isLoading = true
        errorMessage = nil
        hasSearched = true
        defer { isLoading = false }

        do {
            posts = try await APIClient.getFeed(query: trimmed)
            if let userId = authSession.userId {
                recentSearches = Self.record(trimmed, for: userId)
                loadedUserId = userId
            }
        } catch APIClientError.unauthorized {
            posts = []
            errorMessage = APIClientError.unauthorized.localizedDescription
            authSession.signOut()
        } catch {
            posts = []
            errorMessage = error.localizedDescription
        }
    }

    func runRecentSearch(_ query: String, using authSession: AuthSession) async {
        await search(using: authSession, query: query)
    }

    func clearResults() {
        posts = []
        hasSearched = false
        errorMessage = nil
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

    private static func storageKey(for userId: Int) -> String {
        "recentSearches.\(userId)"
    }

    private static func loadStoredSearches(for userId: Int) -> [String] {
        UserDefaults.standard.stringArray(forKey: storageKey(for: userId)) ?? []
    }

    private static func record(_ query: String, for userId: Int) -> [String] {
        var updated = loadStoredSearches(for: userId).filter {
            $0.caseInsensitiveCompare(query) != .orderedSame
        }
        updated.insert(query, at: 0)
        if updated.count > maxRecentSearches {
            updated = Array(updated.prefix(maxRecentSearches))
        }
        UserDefaults.standard.set(updated, forKey: storageKey(for: userId))
        return updated
    }
}

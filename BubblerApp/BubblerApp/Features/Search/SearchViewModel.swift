//
//  SearchViewModel.swift
//  BubblerApp
//

import Combine
import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var exactMatches: [Post] = []
    @Published var related: [Post] = []
    @Published var recentSearches: [String] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published private(set) var hasSearched = false
    @Published private(set) var lastQuery = ""

    private static let maxRecentSearches = 5
    private var loadedUserId: Int?
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    var posts: [Post] {
        exactMatches + related
    }

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

    /// Debounced live search while typing (skips empty / very short drafts).
    func scheduleLiveSearch(using authSession: AuthSession) {
        debounceTask?.cancel()
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            if trimmed.isEmpty {
                clearResults()
            }
            return
        }

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(using: authSession, query: trimmed, recordRecent: false)
        }
    }

    func search(
        using authSession: AuthSession,
        query: String? = nil,
        recordRecent: Bool = true
    ) async {
        let trimmed = (query ?? searchText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            errorMessage = "Enter a search to find bubbles."
            return
        }

        guard authSession.accessToken != nil else {
            exactMatches = []
            related = []
            errorMessage = nil
            return
        }

        searchTask?.cancel()
        searchText = trimmed
        isLoading = true
        errorMessage = nil
        hasSearched = true
        lastQuery = trimmed

        let task = Task {
            do {
                let response = try await APIClient.search(query: trimmed)
                guard !Task.isCancelled else { return }
                exactMatches = Self.prioritizeTopicMatches(
                    response.exactMatches,
                    query: trimmed
                )
                related = response.related
                if recordRecent, let userId = authSession.userId {
                    recentSearches = Self.record(trimmed, for: userId)
                    loadedUserId = userId
                }
            } catch is CancellationError {
                return
            } catch APIClientError.unauthorized {
                guard !Task.isCancelled else { return }
                exactMatches = []
                related = []
                errorMessage = APIClientError.unauthorized.localizedDescription
                authSession.signOut()
            } catch {
                guard !Task.isCancelled else { return }
                exactMatches = []
                related = []
                errorMessage = error.localizedDescription
            }
        }
        searchTask = task
        await task.value
        if !Task.isCancelled, searchTask == task {
            isLoading = false
        }
    }

    func runRecentSearch(_ query: String, using authSession: AuthSession) async {
        debounceTask?.cancel()
        await search(using: authSession, query: query, recordRecent: true)
    }

    func clearResults() {
        searchTask?.cancel()
        debounceTask?.cancel()
        exactMatches = []
        related = []
        hasSearched = false
        lastQuery = ""
        errorMessage = nil
        isLoading = false
    }

    func removePost(id: String) {
        exactMatches.removeAll { $0.id == id }
        related.removeAll { $0.id == id }
    }

    func updatePostContent(id: String, content: String) {
        updateContent(in: &exactMatches, id: id, content: content)
        updateContent(in: &related, id: id, content: content)
    }

    private func updateContent(in posts: inout [Post], id: String, content: String) {
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

    /// When the query equals a known topic, keep same-topic posts first.
    private static func prioritizeTopicMatches(posts: [Post], query: String) -> [Post] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard KnownTopics.all.contains(normalized) else { return posts }

        return posts.enumerated()
            .sorted { lhs, rhs in
                let leftMatch = matchesTopic(lhs.element, topic: normalized)
                let rightMatch = matchesTopic(rhs.element, topic: normalized)
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

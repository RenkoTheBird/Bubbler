//
//  FeedViewModel.swift
//  BubblerApp
//

import Combine
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []

    func loadFeed(token: String) async throws {
        posts = try await APIClient.get("feed/me", token: token)
    }
}

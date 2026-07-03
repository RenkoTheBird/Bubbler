//
//  FeedViewModel.swift
//  BubblerApp
//

import Combine
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    func loadFeed(using authSession: AuthSession) async {
        guard let token = authSession.accessToken else {
            posts = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            posts = try await APIClient.get("feed/me", token: token)
        } catch APIClientError.unauthorized {
            posts = []
            errorMessage = APIClientError.unauthorized.localizedDescription
            authSession.signOut()
        } catch {
            posts = []
            errorMessage = error.localizedDescription
        }
    }
}

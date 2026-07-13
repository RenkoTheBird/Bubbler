//
//  ProfileViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var username: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var hasLoaded = false

    var displayUsername: String {
        if let username, !username.isEmpty {
            return "@\(username)"
        }
        return isLoading ? "Loading..." : "@…"
    }

    func loadProfile(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorMessage = nil

        do {
            let profile = try await APIClient.getProfile()
            username = profile.username
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
}

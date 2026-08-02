//
//  BlockedViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class BlockedViewModel: ObservableObject {
    @Published private(set) var blockedUsers: [BlockedUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published var errorTitle = "Couldn't load blocked users"
    @Published var errorMessage: String?

    private var hasLoaded = false

    func loadBlockedUsers(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorTitle = "Couldn't load blocked users"
        errorMessage = nil

        do {
            blockedUsers = try await APIClient.getBlockedUsers()
            hasLoaded = true
        } catch {
            handleSessionError(
                error,
                using: authSession,
                fallbackMessage: "We couldn't load your blocked users."
            )
        }

        isLoading = false
    }

    func unblock(_ user: BlockedUser, using authSession: AuthSession) async {
        guard !isUpdating else { return }

        isUpdating = true
        errorTitle = "Couldn't unblock user"
        errorMessage = nil

        do {
            _ = try await APIClient.unblockUser(username: user.username)
            blockedUsers.removeAll { $0.id == user.id }
        } catch {
            handleSessionError(
                error,
                using: authSession,
                fallbackMessage: "We couldn't unblock @\(user.username)."
            )
        }

        isUpdating = false
    }

    private func handleSessionError(
        _ error: Error,
        using authSession: AuthSession,
        fallbackMessage: String
    ) {
        if case APIClientError.unauthorized = error {
            authSession.signOut()
            return
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = description.isEmpty ? fallbackMessage : description
    }
}

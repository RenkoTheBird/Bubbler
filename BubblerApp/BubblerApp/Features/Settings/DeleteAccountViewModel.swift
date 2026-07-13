//
//  DeleteAccountViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class DeleteAccountViewModel: ObservableObject {
    @Published var password = ""
    @Published private(set) var accountEmail = ""
    @Published var isLoading = true
    @Published var isDeleting = false
    @Published var errorTitle = "Couldn't load account"
    @Published var errorMessage: String?

    private var hasLoaded = false

    var canDelete: Bool {
        !password.isEmpty && !accountEmail.isEmpty && !isDeleting && !isLoading
    }

    func loadProfile(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorTitle = "Couldn't load account"
        errorMessage = nil

        do {
            let profile = try await APIClient.getProfile()
            accountEmail = profile.email
            hasLoaded = true
        } catch {
            handleSessionError(error, using: authSession, fallbackMessage: "We couldn't load your account details.")
        }

        isLoading = false
    }

    func deleteAccount(using authSession: AuthSession) async {
        guard !password.isEmpty else {
            errorTitle = "Couldn't delete account"
            errorMessage = "Enter your password to confirm."
            return
        }

        guard !accountEmail.isEmpty else {
            errorTitle = "Couldn't delete account"
            errorMessage = "We couldn't confirm your account email. Try reloading this screen."
            return
        }

        isDeleting = true
        errorTitle = "Couldn't delete account"
        errorMessage = nil

        do {
            do {
                _ = try await APIClient.login(email: accountEmail, password: password)
            } catch {
                if case APIClientError.unauthorized = error {
                    password = ""
                    errorMessage = "Incorrect password. Please try again."
                } else {
                    let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = description.isEmpty
                        ? "We couldn't verify your password. Please try again."
                        : description
                }
                isDeleting = false
                return
            }

            try await APIClient.deleteAccount()
            authSession.signOut()
        } catch {
            handleSessionError(
                error,
                using: authSession,
                fallbackMessage: "We couldn't delete your account. Please try again."
            )
        }

        isDeleting = false
    }

    private func handleSessionError(
        _ error: Error,
        using authSession: AuthSession,
        fallbackMessage: String
    ) {
        if case APIClientError.unauthorized = error {
            authSession.signOut()
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = description.isEmpty ? fallbackMessage : description
    }
}

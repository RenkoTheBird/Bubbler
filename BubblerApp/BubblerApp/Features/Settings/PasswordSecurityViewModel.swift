//
//  PasswordSecurityViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class PasswordSecurityViewModel: ObservableObject {
    @Published var emailOrUsername = ""
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmNewPassword = ""
    @Published private(set) var accountEmail = ""
    @Published private(set) var accountUsername = ""
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var errorTitle = "Couldn't load account"
    @Published var errorMessage: String?

    private var hasLoaded = false

    var canReset: Bool {
        !emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !currentPassword.isEmpty
            && !newPassword.isEmpty
            && !confirmNewPassword.isEmpty
            && !isSaving
            && !isLoading
    }

    func loadProfile(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorTitle = "Couldn't load account"
        errorMessage = nil

        do {
            let profile = try await APIClient.getProfile()
            accountEmail = profile.email
            accountUsername = profile.username
            hasLoaded = true
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't load your account details.")
        }

        isLoading = false
    }

    func resetPassword(using authSession: AuthSession) async {
        let identity = emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !identity.isEmpty else {
            errorTitle = "Couldn't reset password"
            errorMessage = "Enter your current email or username."
            return
        }

        guard !currentPassword.isEmpty else {
            errorTitle = "Couldn't reset password"
            errorMessage = "Enter your current password."
            return
        }

        guard newPassword.count >= 5 else {
            errorTitle = "Couldn't reset password"
            errorMessage = "New password must be at least 5 characters."
            return
        }

        guard newPassword.count <= 40 else {
            errorTitle = "Couldn't reset password"
            errorMessage = "New password must be 40 characters or fewer."
            return
        }

        guard newPassword == confirmNewPassword else {
            errorTitle = "Couldn't reset password"
            errorMessage = "New passwords do not match."
            return
        }

        guard newPassword != currentPassword else {
            errorTitle = "Couldn't reset password"
            errorMessage = "New password must be different from your current password."
            return
        }

        isSaving = true
        errorTitle = "Couldn't reset password"
        errorMessage = nil

        do {
            try await APIClient.updatePassword(
                emailOrUsername: identity,
                currentPassword: currentPassword,
                newPassword: newPassword,
                confirmNewPassword: confirmNewPassword
            )
            authSession.signOut()
            authSession.showSuccessMessage("Password updated. Please log in with your new password.")
        } catch {
            handle(
                error,
                using: authSession,
                fallbackMessage: "We couldn't reset your password. Please try again."
            )
        }

        isSaving = false
    }

    private func handle(_ error: Error, using authSession: AuthSession, fallbackMessage: String) {
        if case APIClientError.unauthorized = error {
            authSession.signOut()
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = description.isEmpty ? fallbackMessage : description
    }
}

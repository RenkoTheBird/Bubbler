//
//  EmailSettingsViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class EmailSettingsViewModel: ObservableObject {
    @Published var email = ""
    @Published private(set) var currentEmail = ""
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var errorTitle = "Couldn't load email"
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var hasLoaded = false

    var canSave: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed.lowercased() != currentEmail.lowercased()
            && !isSaving
            && !isLoading
    }

    func loadProfile(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorTitle = "Couldn't load email"
        errorMessage = nil
        successMessage = nil

        do {
            let profile = try await APIClient.getProfile()
            currentEmail = profile.email
            email = profile.email
            hasLoaded = true
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't fetch your current email.")
        }

        isLoading = false
    }

    func saveEmail(using authSession: AuthSession) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorTitle = "Couldn't update email"
            errorMessage = "Enter a valid email address."
            return
        }

        isSaving = true
        errorTitle = "Couldn't update email"
        errorMessage = nil
        successMessage = nil

        do {
            let profile = try await APIClient.updateEmail(trimmed)
            currentEmail = profile.email
            email = profile.email
            successMessage = "Your email was updated successfully."
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't update your email.")
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

//
//  PreferencesSettingsViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class PreferencesSettingsViewModel: ObservableObject {
    @Published var preferences = UserPreferences.placeholder
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var errorTitle = "Couldn't load preferences"
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var hasLoaded = false

    var strategyTotal: Double {
        preferences.strategyWeights.total
    }

    func loadPreferences(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorTitle = "Couldn't load preferences"
        errorMessage = nil

        do {
            preferences = try await APIClient.getPreferences()
            hasLoaded = true
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't fetch your saved preferences.")
        }

        isLoading = false
    }

    func reloadPreferences(using authSession: AuthSession) async {
        hasLoaded = false
        await loadPreferences(using: authSession, force: true)
    }

    func savePreferences(using authSession: AuthSession) async {
        isSaving = true
        errorTitle = "Couldn't save preferences"
        errorMessage = nil
        successMessage = nil

        do {
            let sanitized = preferences.sanitized()
            let savedPreferences = try await APIClient.updatePreferences(sanitized.updatePayload)
            preferences = savedPreferences
            successMessage = "Your recommendation settings were saved successfully."
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't save your preferences.")
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

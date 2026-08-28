//
//  OnboardingViewModel.swift
//  BubblerApp
//

import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published private(set) var preferences = UserPreferences.systemDefaults(userId: 0)
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    func loadPreferences(using authSession: AuthSession) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            preferences = try await APIClient.getPreferences().sanitized()
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't load your feed settings.")
        }
    }

    func selectPreset(_ preset: FeedPreset) {
        preferences.applyPreset(preset)
    }

    func completeOnboarding(using authSession: AuthSession) async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var payload = preferences.sanitized()
        payload.onboardingCompleted = true

        do {
            let saved = try await APIClient.updatePreferences(payload.updatePayload)
            preferences = saved.sanitized()
            authSession.markOnboardingComplete()
            return true
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't save your feed settings.")
            return false
        }
    }

    func useRecommendedDefaults(using authSession: AuthSession) async -> Bool {
        if let userId = authSession.userId {
            preferences = UserPreferences.systemDefaults(userId: userId)
        } else {
            preferences = UserPreferences.systemDefaults(userId: preferences.userId)
        }
        return await completeOnboarding(using: authSession)
    }

    private func handle(_ error: Error, using authSession: AuthSession, fallbackMessage: String) {
        if case APIClientError.unauthorized = error {
            authSession.signOut()
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = description.isEmpty ? fallbackMessage : description
    }
}

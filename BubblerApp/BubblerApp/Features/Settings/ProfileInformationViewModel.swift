//
//  ProfileInformationViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

@MainActor
final class ProfileInformationViewModel: ObservableObject {
    @Published private(set) var profile: User?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var hasLoaded = false

    private static let memberSinceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var memberSinceText: String {
        guard let createdAt = profile?.created_at else { return "—" }
        return Self.memberSinceFormatter.string(from: createdAt)
    }

    func loadProfile(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorMessage = nil

        do {
            profile = try await APIClient.getProfile()
            hasLoaded = true
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't load your profile information.")
        }

        isLoading = false
    }

    func reload(using authSession: AuthSession) async {
        hasLoaded = false
        await loadProfile(using: authSession, force: true)
    }

    private func handle(_ error: Error, using authSession: AuthSession, fallbackMessage: String) {
        if case APIClientError.unauthorized = error {
            authSession.signOut()
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = description.isEmpty ? fallbackMessage : description
    }
}

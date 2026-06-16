//
//  AuthSession.swift
//  BubblerApp
//

import Combine
import FirebaseAuth
import Foundation

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var user: User?
    @Published var authError: String?
    @Published var successMessage: String?
    @Published var isWorking = false

    private var authListener: AuthStateDidChangeListenerHandle?

    var isSignedIn: Bool {
        user != nil
    }

    init() {
        user = Auth.auth().currentUser
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    func signIn(email: String, password: String) async {
        _ = await performAuthAction {
            try await Auth.auth().signIn(withEmail: normalizedEmail(email), password: password)
        }
    }

    func createAccount(email: String, password: String, confirmPassword: String) async {
        let trimmedEmail = normalizedEmail(email)

        guard !trimmedEmail.isEmpty else {
            authError = "Enter your email address."
            return
        }

        guard password.count >= 6 else {
            authError = "Password must be at least 6 characters."
            return
        }

        guard password == confirmPassword else {
            authError = "Passwords do not match."
            return
        }

        let didCreateAccount = await performAuthAction {
            try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
        }

        if didCreateAccount {
            successMessage = "Account created successfully!"
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
            authError = nil
            successMessage = nil
        } catch {
            authError = error.localizedDescription
        }
    }

    func clearSuccessMessage() {
        successMessage = nil
    }

    private func performAuthAction(_ action: () async throws -> AuthDataResult) async -> Bool {
        authError = nil
        successMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await action()
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

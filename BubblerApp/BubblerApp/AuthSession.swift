//
//  AuthSession.swift
//  BubblerApp
//

import Combine
import Foundation

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var user: BackendUser?
    @Published var authError: String?
    @Published var successMessage: String?
    @Published var isWorking = false
    @Published private(set) var isRestoringSession = false

    private let client: BackendClient
    private let storage: UserDefaults
    private let sessionUserKey = "bubbler.sessionUser"

    var isSignedIn: Bool {
        user != nil
    }

    init(client: BackendClient = .shared, storage: UserDefaults = .standard) {
        self.client = client
        self.storage = storage
        self.user = Self.storedUser(from: storage, key: sessionUserKey)
    }

    func signIn(email: String, password: String) async {
        let trimmedEmail = normalizedEmail(email)

        guard !trimmedEmail.isEmpty else {
            authError = "Enter your email address."
            return
        }

        guard !password.isEmpty else {
            authError = "Enter your password."
            return
        }

        _ = await performAuthAction {
            saveSession(try await client.loginSession(email: trimmedEmail, password: password))
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
            saveSession(try await client.registerSession(
                username: username(from: trimmedEmail),
                email: trimmedEmail,
                password: password
            ))
        }

        if didCreateAccount {
            successMessage = "Account created successfully!"
        }
    }

    func restoreSession() async {
        guard let token = SessionTokenStore.load() else {
            return
        }

        authError = nil
        isRestoringSession = true
        defer { isRestoringSession = false }

        do {
            saveSession(try await client.session(token: token))
        } catch {
            clearStoredSession()
        }
    }

    func signOut() {
        clearStoredSession()
        authError = nil
        successMessage = nil
    }

    func clearSuccessMessage() {
        successMessage = nil
    }

    private func performAuthAction(_ action: () async throws -> Void) async -> Bool {
        authError = nil
        successMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await action()
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func saveSession(_ response: AuthResponse) {
        user = response.user
        SessionTokenStore.save(response.sessionToken)

        if let encodedUser = try? JSONEncoder().encode(response.user) {
            storage.set(encodedUser, forKey: sessionUserKey)
        }
    }

    private func clearStoredSession() {
        user = nil
        SessionTokenStore.delete()
        storage.removeObject(forKey: sessionUserKey)
    }

    private static func storedUser(from storage: UserDefaults, key: String) -> BackendUser? {
        guard let data = storage.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(BackendUser.self, from: data)
    }

    private func username(from email: String) -> String {
        let prefix = email.split(separator: "@").first.map(String.init) ?? "bubbler"
        let safeCharacters = prefix.map { character in
            character.isLetter || character.isNumber ? character : "_"
        }

        let username = String(safeCharacters).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return username.isEmpty ? "bubbler" : username
    }
}

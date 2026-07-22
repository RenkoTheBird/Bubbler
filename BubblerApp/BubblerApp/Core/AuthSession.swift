//
//  AuthSession.swift
//  BubblerApp
//

import Combine
import Foundation

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var accessToken: String?
    @Published private(set) var userId: Int?
    @Published var authError: String?
    @Published var successMessage: String?
    @Published var isWorking = false

    var isSignedIn: Bool {
        accessToken != nil
    }

    init() {
        accessToken = KeychainStore.loadAccessToken()
        userId = Self.restoredUserId(from: accessToken)
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

        _ = await performAuthAction(
            unauthorizedErrorMessage: "Incorrect username or password."
        ) {
            try await APIClient.login(
                email: trimmedEmail,
                password: password
            )
        }
    }

    func createAccount(
        username: String,
        email: String,
        password: String,
        confirmPassword: String
    ) async {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = normalizedEmail(email)

        guard !trimmedUsername.isEmpty else {
            authError = "Enter a username."
            return
        }

        guard trimmedUsername.count <= 20 else {
            authError = "Username must be 20 characters or fewer."
            return
        }

        guard !trimmedEmail.isEmpty else {
            authError = "Enter your email address."
            return
        }

        guard password.count >= 5 else {
            authError = "Password must be at least 5 characters."
            return
        }

        guard password.count <= 40 else {
            authError = "Password must be 40 characters or fewer."
            return
        }

        guard password == confirmPassword else {
            authError = "Passwords do not match."
            return
        }

        let didCreateAccount = await performAuthAction {
            try await APIClient.register(
                username: trimmedUsername,
                email: trimmedEmail,
                password: password
            )
        }

        if didCreateAccount {
            successMessage = "Account created successfully!"
        }
    }

    func signOut() {
        KeychainStore.deleteAccessToken()
        accessToken = nil
        userId = nil
        authError = nil
        successMessage = nil
    }

    func clearSuccessMessage() {
        successMessage = nil
    }

    func showSuccessMessage(_ message: String) {
        successMessage = message
    }

    private func performAuthAction(
        unauthorizedErrorMessage: String? = nil,
        _ action: () async throws -> AuthResponse
    ) async -> Bool {
        authError = nil
        successMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await action()
            try KeychainStore.saveAccessToken(response.accessToken)
            accessToken = response.accessToken
            userId = response.userId
            return true
        } catch APIClientError.unauthorized {
            authError = unauthorizedErrorMessage
                ?? APIClientError.unauthorized.localizedDescription
            return false
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func restoredUserId(from token: String?) -> Int? {
        guard let token else { return nil }

        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - payload.count % 4
        if padding < 4 {
            payload += String(repeating: "=", count: padding)
        }

        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subject = json["sub"] as? String,
              let userId = Int(subject) else {
            return nil
        }

        return userId
    }
}

//
//  BackendConnection.swift
//  BubblerApp
//

import Combine
import Foundation

nonisolated struct BackendHealth: Decodable, Sendable {
    let status: String
    let database: String
}

nonisolated struct BackendUser: Codable, Equatable, Sendable {
    let id: Int
    let username: String
    let email: String
}

nonisolated struct AuthResponse: Decodable, Sendable {
    let user: BackendUser
    let sessionToken: String
    let expiresAt: Int?

    enum CodingKeys: String, CodingKey {
        case user
        case sessionToken = "session_token"
        case expiresAt = "expires_at"
    }
}

nonisolated enum BackendConnectionState: Equatable, Sendable {
    case checking
    case connected(database: String)
    case unavailable
}

nonisolated enum BackendClientError: LocalizedError {
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The backend returned an invalid response."
        case .serverMessage(let message):
            return message
        }
    }
}

actor BackendClient {
    static let shared = BackendClient()

    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "http://127.0.0.1:8000")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func health() async throws -> BackendHealth {
        let url = baseURL.appending(path: "health")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let data = try await send(request)

        return try JSONDecoder().decode(BackendHealth.self, from: data)
    }

    func login(email: String, password: String) async throws -> BackendUser {
        let request = try jsonRequest(
            path: "login",
            body: [
                "email": email,
                "password": password
            ]
        )
        let data = try await send(request)

        return try JSONDecoder().decode(AuthResponse.self, from: data).user
    }

    func loginSession(email: String, password: String) async throws -> AuthResponse {
        let request = try jsonRequest(
            path: "login",
            body: [
                "email": email,
                "password": password
            ]
        )
        let data = try await send(request)

        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func register(username: String, email: String, password: String) async throws -> BackendUser {
        let request = try jsonRequest(
            path: "register",
            body: [
                "username": username,
                "email": email,
                "password": password
            ]
        )
        let data = try await send(request)

        return try JSONDecoder().decode(AuthResponse.self, from: data).user
    }

    func registerSession(username: String, email: String, password: String) async throws -> AuthResponse {
        let request = try jsonRequest(
            path: "register",
            body: [
                "username": username,
                "email": email,
                "password": password
            ]
        )
        let data = try await send(request)

        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func session(token: String) async throws -> AuthResponse {
        let url = baseURL.appending(path: "session")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data = try await send(request)

        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    private func jsonRequest(path: String, body: [String: String]) throws -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorMessage = decodeErrorMessage(from: data) {
                throw BackendClientError.serverMessage(errorMessage)
            }

            throw URLError(.badServerResponse)
        }

        return data
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let detail = object["detail"] as? String {
            return detail
        }

        if let detail = object["detail"] as? [String: Any],
           let message = detail["message"] as? String {
            return message
        }

        return nil
    }
}

@MainActor
final class BackendConnection: ObservableObject {
    @Published private(set) var state: BackendConnectionState = .checking

    private let client: BackendClient

    init(client: BackendClient = .shared) {
        self.client = client
    }

    func refresh() async {
        state = .checking

        do {
            let health = try await client.health()
            state = health.status == "ok"
                ? .connected(database: health.database)
                : .unavailable
        } catch {
            state = .unavailable
        }
    }
}

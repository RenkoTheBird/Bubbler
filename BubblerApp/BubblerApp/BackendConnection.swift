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

nonisolated enum BackendConnectionState: Equatable, Sendable {
    case checking
    case connected(database: String)
    case unavailable
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

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(BackendHealth.self, from: data)
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

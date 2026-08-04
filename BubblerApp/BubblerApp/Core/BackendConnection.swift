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

@MainActor
final class BackendConnection: ObservableObject {
    @Published private(set) var state: BackendConnectionState = .checking

    func refresh() async {
        state = .checking

        do {
            let health = try await APIClient.health()
            state = health.status == "ok"
                ? .connected(database: health.database)
                : .unavailable
        } catch {
            state = .unavailable
        }
    }
}

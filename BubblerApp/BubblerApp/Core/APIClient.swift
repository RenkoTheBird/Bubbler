//
//  APIClient.swift
//  BubblerApp
//

import Foundation

enum APIConfig {
    static let baseURL = URL(string: "http://127.0.0.1:8000")!
}

struct AuthResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let userId: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case userId = "user_id"
    }
}

private struct RegisterBody: Encodable {
    let username: String
    let email: String
    let password: String
}

private struct CreatePostBody: Encodable {
    let post: String
    let topic: String
}

private struct UpdatePostBody: Encodable {
    let post: String
}

private struct PostTopicMutationBody: Encodable {
    let topic: String
}

private struct EmailUpdateBody: Encodable {
    let email: String
}

private struct APIErrorBody: Decodable {
    let detail: String
}

enum APIClientError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from the server."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .serverError(_, let message):
            return message
        }
    }
}

enum APIClient {
    static func login(email: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: APIConfig.baseURL.appending(path: "auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedBody([
            "username": email,
            "password": password,
        ])
        return try await perform(request)
    }

    static func register(username: String, email: String, password: String) async throws -> AuthResponse {
        var request = URLRequest(url: APIConfig.baseURL.appending(path: "auth/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RegisterBody(username: username, email: email, password: password)
        )
        return try await perform(request)
    }

    static func get<T: Decodable>(_ path: String, token: String) async throws -> T {
        var request = URLRequest(url: APIConfig.baseURL.appending(path: path))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data = try await performData(request)
        return try apiJSONDecoder.decode(T.self, from: data)
    }

    static func authorizedRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        contentType: String? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Data {
        guard let token = KeychainStore.loadAccessToken() else {
            throw APIClientError.unauthorized
        }

        var components = URLComponents(
            url: APIConfig.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw APIClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body
        return try await performData(request)
    }

    static func getProfile() async throws -> User {
        let data = try await authorizedRequest(path: "user/me/profile")
        return try apiJSONDecoder.decode(User.self, from: data)
    }

    /// Public profile for any user by username.
    static func getUser(username: String) async throws -> PublicUser {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let data = try await authorizedRequest(path: "user/\(encoded)/profile")
        return try apiJSONDecoder.decode(PublicUser.self, from: data)
    }

    static func updateEmail(_ email: String) async throws -> User {
        let body = try JSONEncoder().encode(EmailUpdateBody(email: email))
        let data = try await authorizedRequest(
            path: "user/me/profile/email",
            method: "PUT",
            body: body,
            contentType: "application/json"
        )
        return try apiJSONDecoder.decode(User.self, from: data)
    }

    static func getPreferences() async throws -> UserPreferences {
        let data = try await authorizedRequest(path: "user/me/preferences")
        return try apiJSONDecoder.decode(UserPreferences.self, from: data)
    }

    static func updatePreferences(_ payload: PreferencesUpdatePayload) async throws -> UserPreferences {
        let body = try JSONEncoder().encode(payload)
        let data = try await authorizedRequest(
            path: "user/me/preferences",
            method: "PUT",
            body: body,
            contentType: "application/json"
        )
        return try apiJSONDecoder.decode(UserPreferences.self, from: data)
    }

    /// Ranked feed. Optional `query` maps to `q` and seeds similar/opposite candidates.
    static func getFeed(query: String? = nil) async throws -> [Post] {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let queryItems: [URLQueryItem]? = trimmed.isEmpty
            ? nil
            : [URLQueryItem(name: "q", value: trimmed)]
        let data = try await authorizedRequest(path: "feed/me", queryItems: queryItems)
        return try apiJSONDecoder.decode([Post].self, from: data)
    }

    /// Hybrid search: keyword/topic/username hits, then semantic related posts.
    static func search(query: String) async throws -> SearchResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = try await authorizedRequest(
            path: "search",
            queryItems: [URLQueryItem(name: "q", value: trimmed)]
        )
        return try apiJSONDecoder.decode(SearchResponse.self, from: data)
    }

    static func getSessionFeed(diversify: Bool = false) async throws -> GraphSessionFeed {
        let queryItems = diversify
            ? [URLQueryItem(name: "diversify", value: "true")]
            : nil
        let data = try await authorizedRequest(path: "feed/me/session", queryItems: queryItems)
        return try apiJSONDecoder.decode(GraphSessionFeed.self, from: data)
    }

    static func getNextGraphPosts(for postID: String) async throws -> [Post] {
        let data = try await authorizedRequest(path: "graph/posts/\(postID)/next")
        return try apiJSONDecoder.decode([Post].self, from: data)
    }

    static func getMyPosts() async throws -> [Post] {
        let data = try await authorizedRequest(path: "user/me/posts")
        return try apiJSONDecoder.decode([Post].self, from: data)
    }

    static func getUserPosts(username: String) async throws -> [Post] {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let data = try await authorizedRequest(path: "user/\(encoded)/posts")
        return try apiJSONDecoder.decode([Post].self, from: data)
    }

    /// Recent interactions for the profile Bubble Trail (server caps at 20).
    static func getMyInteractions() async throws -> [Interaction] {
        let data = try await authorizedRequest(path: "user/me")
        return try apiJSONDecoder.decode([Interaction].self, from: data)
    }

    static func createPost(content: String, topic: String) async throws -> Post {
        let body = try JSONEncoder().encode(CreatePostBody(post: content, topic: topic))
        let data = try await authorizedRequest(
            path: "user/me/posts",
            method: "POST",
            body: body,
            contentType: "application/json"
        )
        return try apiJSONDecoder.decode(Post.self, from: data)
    }

    static func updatePost(id: String, content: String) async throws {
        let body = try JSONEncoder().encode(UpdatePostBody(post: content))
        _ = try await authorizedRequest(
            path: "user/me/posts/\(id)",
            method: "PUT",
            body: body,
            contentType: "application/json"
        )
    }

    static func deletePost(id: String) async throws {
        _ = try await authorizedRequest(path: "user/me/posts/\(id)", method: "DELETE")
    }

    static func addPostTopic(postId: String, topic: String) async throws -> Post {
        let body = try JSONEncoder().encode(PostTopicMutationBody(topic: topic))
        let data = try await authorizedRequest(
            path: "user/me/posts/\(postId)/topics",
            method: "POST",
            body: body,
            contentType: "application/json"
        )
        return try apiJSONDecoder.decode(Post.self, from: data)
    }

    static func removePostTopic(postId: String, topic: String) async throws -> Post {
        let data = try await authorizedRequest(
            path: "user/me/posts/\(postId)/topics/\(topic)",
            method: "DELETE"
        )
        return try apiJSONDecoder.decode(Post.self, from: data)
    }

    static func recordInteraction(_ payload: GraphInteractionPayload) async throws {
        let body = try JSONEncoder().encode(payload)
        _ = try await authorizedRequest(
            path: "user/me/interactions",
            method: "POST",
            body: body,
            contentType: "application/json"
        )
    }

    static func deleteLike(postId: String) async throws {
        _ = try await authorizedRequest(
            path: "user/me/interactions/\(postId)/like",
            method: "DELETE"
        )
    }

    static func deleteAccount() async throws {
        _ = try await authorizedRequest(path: "user/me", method: "DELETE")
    }

    private static let apiJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(dateString)"
            )
        }
        return decoder
    }()

    private static func perform(_ request: URLRequest) async throws -> AuthResponse {
        let data = try await performData(request)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    private static func performData(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIClientError.unauthorized
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorBody.self, from: data).detail)
                ?? "Request failed with status \(httpResponse.statusCode)."
            throw APIClientError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    private static func formEncodedBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed
        let pairs = fields.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }
}

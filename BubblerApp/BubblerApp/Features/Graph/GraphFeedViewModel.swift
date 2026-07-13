import Combine
import Foundation

@MainActor
final class GraphFeedViewModel: ObservableObject {
    @Published private(set) var currentNode: GraphFeedNode?
    @Published private(set) var nextChoices: [GraphFeedNode] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private var preferences = UserPreferences.placeholder
    private var sessionQueue: [GraphFeedNode] = []
    private var currentPostStartedAt: Date?

    var hasCurrentPost: Bool {
        currentNode != nil
    }

    var currentTopicName: String {
        currentNode?.topicName ?? "Topicless bubble"
    }

    var isCurrentTopicPreferred: Bool {
        currentNode?.isPreferredTopic == true
    }

    func load(using authSession: AuthSession) async {
        guard !isLoading else { return }
        await loadSession(using: authSession, message: "Building your graph session.")
    }

    func refreshSession(using authSession: AuthSession) async {
        await loadSession(using: authSession, message: "Generating a new topic path.")
    }

    func choose(_ node: GraphFeedNode, using authSession: AuthSession) async {
        await advance(
            byRecording: .explore,
            explicitNextNode: node,
            using: authSession,
            fallbackMessage: "Following a connected post."
        )
    }

    func likeCurrentPost(using authSession: AuthSession) async {
        await advance(
            byRecording: .like,
            explicitNextNode: nil,
            using: authSession,
            fallbackMessage: "Saved as a positive interaction."
        )
    }

    func skipCurrentPost(using authSession: AuthSession) async {
        await advance(
            byRecording: .skip,
            explicitNextNode: nil,
            using: authSession,
            fallbackMessage: "Skipping ahead to the next bubble."
        )
    }

    func updateCurrentPostContent(_ content: String) {
        guard let currentNode else { return }
        let existing = currentNode.post
        let updatedPost = Post(
            id: existing.id,
            userId: existing.userId,
            content: content,
            createdAt: existing.createdAt,
            topic: existing.topic,
            embedding: existing.embedding
        )
        self.currentNode = GraphFeedNode(
            post: updatedPost,
            isPreferredTopic: currentNode.isPreferredTopic,
            isBlacklistedTopic: currentNode.isBlacklistedTopic
        )
    }

    func deleteCurrentPost(using authSession: AuthSession) async {
        guard let currentNode else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await APIClient.deletePost(id: currentNode.id)
            authSession.showSuccessMessage("Post deleted.")

            nextChoices.removeAll { $0.id == currentNode.id }
            sessionQueue.removeAll { $0.id == currentNode.id }

            if let nextNode = nextAutomaticNode(excluding: currentNode.id) {
                await setCurrentNode(nextNode, using: authSession)
                if errorMessage == nil {
                    statusMessage = "Deleted your post and moved ahead."
                }
            } else {
                await loadSession(using: authSession, message: "Deleted your post. Loading a fresh session.")
            }
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't delete that post.")
        }

        isSubmitting = false
    }

    func viewTimeText(at date: Date) -> String {
        let elapsedSeconds = Int(viewTime(at: date).rounded(.down))
        return "\(elapsedSeconds)s tracked"
    }

    private func loadSession(using authSession: AuthSession, message: String) async {
        isLoading = true
        errorMessage = nil
        statusMessage = message

        do {
            preferences = try await APIClient.getPreferences().sanitized()

            let sessionNodes = try await fetchUsableSessionNodes()
            guard let firstNode = sessionNodes.first else {
                throw GraphFeedError.noUsablePosts
            }

            sessionQueue = Array(sessionNodes.dropFirst())
            await setCurrentNode(firstNode, using: authSession)

            if errorMessage == nil {
                statusMessage = statusMessage(for: firstNode, defaultMessage: "Session ready.")
            }
        } catch {
            currentNode = nil
            nextChoices = []
            sessionQueue = []
            handle(error, using: authSession, fallbackMessage: "We couldn't build a graph session right now.")
        }

        isLoading = false
    }

    private func advance(
        byRecording interactionType: GraphInteractionType,
        explicitNextNode: GraphFeedNode?,
        using authSession: AuthSession,
        fallbackMessage: String
    ) async {
        guard let currentNode else {
            await loadSession(using: authSession, message: "Building your graph session.")
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            try await recordInteraction(for: currentNode, type: interactionType)

            if let explicitNextNode {
                await setCurrentNode(explicitNextNode, using: authSession)
                if errorMessage == nil {
                    statusMessage = statusMessage(for: explicitNextNode, defaultMessage: fallbackMessage)
                }
            } else if let nextNode = nextAutomaticNode(excluding: currentNode.id) {
                await setCurrentNode(nextNode, using: authSession)
                if errorMessage == nil {
                    statusMessage = statusMessage(for: nextNode, defaultMessage: fallbackMessage)
                }
            } else {
                await loadSession(using: authSession, message: "Loading a fresh set of posts.")
            }
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't save that interaction.")
        }

        isSubmitting = false
    }

    private func setCurrentNode(_ node: GraphFeedNode, using authSession: AuthSession) async {
        guard !node.isBlacklistedTopic else {
            await loadSession(
                using: authSession,
                message: "That topic is blacklisted, so the session is being regenerated."
            )
            return
        }

        currentNode = node
        currentPostStartedAt = Date()

        do {
            nextChoices = try await loadChoices(for: node)

            if nextChoices.isEmpty, sessionQueue.isEmpty {
                statusMessage = "No connected posts were available, so the next action will pull a fresh session."
            }
        } catch {
            nextChoices = []
            handle(error, using: authSession, fallbackMessage: "We couldn't load the connected posts.")
        }
    }

    private func fetchUsableSessionNodes(maxAttempts: Int = 3) async throws -> [GraphFeedNode] {
        for _ in 0 ..< maxAttempts {
            let posts = try await APIClient.getSessionFeed()
            let nodes = rankedNodes(from: posts)

            guard let proposedCurrent = nodes.first else {
                continue
            }

            guard !proposedCurrent.isBlacklistedTopic else {
                continue
            }

            let remainingNodes = nodes
                .dropFirst()
                .filter { !$0.isBlacklistedTopic }

            return [proposedCurrent] + remainingNodes
        }

        throw GraphFeedError.noUsablePosts
    }

    private func loadChoices(for node: GraphFeedNode) async throws -> [GraphFeedNode] {
        let posts = try await APIClient.getNextGraphPosts(for: node.id)
        return rankedNodes(from: posts)
            .filter { choice in
                choice.id != node.id && !choice.isBlacklistedTopic
            }
    }

    private func nextAutomaticNode(excluding currentID: String) -> GraphFeedNode? {
        if let choice = nextChoices.first(where: { $0.id != currentID }) {
            return choice
        }

        while !sessionQueue.isEmpty {
            let nextNode = sessionQueue.removeFirst()
            if nextNode.id != currentID, !nextNode.isBlacklistedTopic {
                return nextNode
            }
        }

        return nil
    }

    private func rankedNodes(from posts: [Post]) -> [GraphFeedNode] {
        let uniquePosts = uniqued(posts)
        let nodes = uniquePosts.map(makeNode(from:))

        return nodes
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isPreferredTopic != rhs.element.isPreferredTopic {
                    return lhs.element.isPreferredTopic && !rhs.element.isPreferredTopic
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func makeNode(from post: Post) -> GraphFeedNode {
        let normalizedTopic = normalizedTopicName(from: post.topic)

        return GraphFeedNode(
            post: post,
            isPreferredTopic: contains(normalizedTopic, in: preferences.preferredTopics),
            isBlacklistedTopic: contains(normalizedTopic, in: preferences.blacklistedTopics)
        )
    }

    private func recordInteraction(for node: GraphFeedNode, type: GraphInteractionType) async throws {
        let payload = GraphInteractionPayload(
            postId: node.id,
            type: type,
            viewTime: viewTime(at: Date())
        )
        try await APIClient.recordInteraction(payload)
    }

    private func viewTime(at date: Date) -> TimeInterval {
        guard let currentPostStartedAt else {
            return 0
        }

        return max(0, date.timeIntervalSince(currentPostStartedAt))
    }

    private func normalizedTopicName(from topic: String?) -> String? {
        guard let topic else {
            return nil
        }

        let normalized = TopicPreferenceList.normalizedTopic(from: topic)
        return normalized.isEmpty ? nil : normalized
    }

    private func contains(_ normalizedTopic: String?, in topics: [String]) -> Bool {
        guard let normalizedTopic else {
            return false
        }

        return topics.contains { topic in
            topic.caseInsensitiveCompare(normalizedTopic) == .orderedSame
        }
    }

    private func uniqued(_ posts: [Post]) -> [Post] {
        var seen = Set<String>()

        return posts.filter { post in
            seen.insert(post.id).inserted
        }
    }

    private func statusMessage(for node: GraphFeedNode, defaultMessage: String) -> String {
        if node.isPreferredTopic, let topicName = node.topicName {
            return "Preferred topic active: \(topicName)."
        }

        if let topicName = node.topicName {
            return "Current topic: \(topicName)."
        }

        return defaultMessage
    }

    private func handle(_ error: Error, using authSession: AuthSession, fallbackMessage: String) {
        if case APIClientError.unauthorized = error {
            authSession.signOut()
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = description.isEmpty ? fallbackMessage : description
    }
}

private enum GraphFeedError: LocalizedError {
    case noUsablePosts

    var errorDescription: String? {
        switch self {
        case .noUsablePosts:
            return "No session posts matched your current topic rules."
        }
    }
}

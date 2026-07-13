import Foundation
import Combine

@MainActor
final class CreatePostViewModel: ObservableObject {
    @Published var content = ""
    @Published var selectedTopic = KnownTopics.defaultTopic
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let editingPostID: String?
    private let originalTopic: String?

    var isEditing: Bool { editingPostID != nil }

    var canSubmit: Bool {
        !isSubmitting && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(post: Post? = nil) {
        editingPostID = post?.id
        if let post {
            content = post.content
            if let topic = post.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
               !topic.isEmpty,
               let match = KnownTopics.all.first(where: {
                   $0.caseInsensitiveCompare(topic) == .orderedSame
               }) {
                selectedTopic = match
                originalTopic = match
            } else {
                originalTopic = post.topic
            }
        } else {
            originalTopic = nil
        }
    }

    func submit(using authSession: AuthSession) async -> String? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            errorMessage = "Write something before posting."
            return nil
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            if let editingPostID {
                try await APIClient.updatePost(id: editingPostID, content: trimmedContent)
                try await syncEditedTopic(postId: editingPostID)
                authSession.showSuccessMessage("Post updated!")
            } else {
                _ = try await APIClient.createPost(
                    content: trimmedContent,
                    topic: selectedTopic
                )
                authSession.showSuccessMessage("Post published!")
            }
            return trimmedContent
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Adds the newly chosen topic, then removes the previous one when it changed.
    private func syncEditedTopic(postId: String) async throws {
        let topicChanged = originalTopic.map {
            $0.caseInsensitiveCompare(selectedTopic) != .orderedSame
        } ?? true

        guard topicChanged else { return }

        _ = try await APIClient.addPostTopic(postId: postId, topic: selectedTopic)

        if let originalTopic,
           originalTopic.caseInsensitiveCompare(selectedTopic) != .orderedSame {
            _ = try await APIClient.removePostTopic(postId: postId, topic: originalTopic)
        }
    }
}

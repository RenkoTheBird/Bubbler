import Foundation
import Combine

@MainActor
final class CreatePostViewModel: ObservableObject {
    @Published var content = ""
    @Published var selectedTopic = KnownTopics.defaultTopic
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !isSubmitting && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit(using authSession: AuthSession) async -> Post? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            errorMessage = "Write something before posting."
            return nil
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let post = try await APIClient.createPost(
                content: trimmedContent,
                topic: selectedTopic
            )
            authSession.showSuccessMessage("Post published!")
            return post
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

import Foundation
import Combine

@MainActor
final class ReportPostViewModel: ObservableObject {
    @Published var selectedReason: ReportReason?
    @Published var comments = ""
    @Published var alsoBlockUser = false
    @Published var errorMessage: String?
    @Published private(set) var isSubmitting = false

    var canSubmit: Bool {
        selectedReason != nil && !isSubmitting
    }

    /// Cap and treat notes as untrusted plain text (backend enforces the same limit).
    func updateComments(_ value: String) {
        if value.count <= ReportDetailsLimits.maxLength {
            comments = value
        } else {
            comments = String(value.prefix(ReportDetailsLimits.maxLength))
        }
    }

    /// Report submit is UI-only until the review-queue API lands.
    /// When [alsoBlockUser] is on, the existing block endpoint is called immediately.
    func submit(blockUsername: String?, using authSession: AuthSession) async -> Bool {
        guard selectedReason != nil else {
            errorMessage = "Choose a reason before submitting."
            return false
        }

        if alsoBlockUser {
            let username = blockUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !username.isEmpty else {
                errorMessage = "We couldn't block this user."
                return false
            }

            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }

            do {
                _ = try await APIClient.blockUser(username: username)
            } catch {
                if case APIClientError.unauthorized = error {
                    authSession.signOut()
                }
                let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                errorMessage = description.isEmpty
                    ? "We couldn't block this user."
                    : description
                return false
            }
        }

        errorMessage = nil
        return true
    }
}

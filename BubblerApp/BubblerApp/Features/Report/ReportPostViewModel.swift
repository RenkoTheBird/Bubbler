import Foundation
import Combine

@MainActor
final class ReportPostViewModel: ObservableObject {
    @Published var selectedReason: ReportReason?
    @Published var comments = ""
    @Published var errorMessage: String?

    var canSubmit: Bool {
        selectedReason != nil
    }

    /// UI-only submit. The review-queue API is not wired yet.
    func submit() -> Bool {
        guard selectedReason != nil else {
            errorMessage = "Choose a reason before submitting."
            return false
        }
        errorMessage = nil
        return true
    }
}

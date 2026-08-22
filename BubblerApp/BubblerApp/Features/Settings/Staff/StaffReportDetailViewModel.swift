import Foundation
import Combine

@MainActor
final class StaffReportDetailViewModel: ObservableObject {
    @Published private(set) var report: StaffReport?
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published var errorTitle = "Couldn't load report"
    @Published var errorMessage: String?

    private let reportId: String

    init(reportId: String, initialReport: StaffReport? = nil) {
        self.reportId = reportId
        self.report = initialReport
    }

    func load(using authSession: AuthSession, force: Bool = false) async {
        if report != nil && !force { return }

        isLoading = true
        errorTitle = "Couldn't load report"
        errorMessage = nil

        do {
            report = try await APIClient.getStaffReport(id: reportId)
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't load this report.")
        }

        isLoading = false
    }

    func updateStatus(_ status: StaffReportStatus, using authSession: AuthSession) async {
        guard !isUpdating else { return }

        isUpdating = true
        errorTitle = "Couldn't update report"
        errorMessage = nil

        do {
            report = try await APIClient.updateStaffReportStatus(id: reportId, status: status)
        } catch {
            handle(
                error,
                using: authSession,
                fallbackMessage: "We couldn't update this report's status."
            )
        }

        isUpdating = false
    }

    func updateLegalHold(_ legalHold: Bool, using authSession: AuthSession) async {
        guard !isUpdating else { return }

        isUpdating = true
        errorTitle = "Couldn't update legal hold"
        errorMessage = nil

        do {
            report = try await APIClient.updateStaffReportLegalHold(
                id: reportId,
                legalHold: legalHold
            )
        } catch {
            handle(
                error,
                using: authSession,
                fallbackMessage: "We couldn't update this report's legal hold."
            )
        }

        isUpdating = false
    }

    private func handle(
        _ error: Error,
        using authSession: AuthSession,
        fallbackMessage: String
    ) {
        if case APIClientError.unauthorized = error {
            authSession.signOut()
            return
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = description.isEmpty ? fallbackMessage : description
    }
}

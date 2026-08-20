import Foundation
import Combine

/// Staff queue reason filter. `nil` = all reasons; illegal isolates the severe bucket.
enum StaffReportReasonFilter: String, CaseIterable, Identifiable {
    case all
    case illegalContent = "illegal_content"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All reasons"
        case .illegalContent: "Illegal / CSAM"
        }
    }

    var apiValue: String? {
        switch self {
        case .all: nil
        case .illegalContent: rawValue
        }
    }
}

@MainActor
final class StaffReportsViewModel: ObservableObject {
    @Published private(set) var reports: [StaffReport] = []
    @Published var selectedStatus: StaffReportStatus = .open
    @Published var selectedReason: StaffReportReasonFilter = .all
    @Published private(set) var isLoading = false
    @Published var errorTitle = "Couldn't load reports"
    @Published var errorMessage: String?

    private var hasLoaded = false

    func loadReports(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorTitle = "Couldn't load reports"
        errorMessage = nil

        do {
            reports = try await APIClient.listStaffReports(
                status: selectedStatus,
                reason: selectedReason.apiValue
            )
            hasLoaded = true
        } catch {
            handle(error, using: authSession, fallbackMessage: "We couldn't load the report queue.")
        }

        isLoading = false
    }

    func changeStatusFilter(_ status: StaffReportStatus, using authSession: AuthSession) async {
        guard selectedStatus != status || !hasLoaded else { return }
        selectedStatus = status
        hasLoaded = false
        await loadReports(using: authSession, force: true)
    }

    func changeReasonFilter(_ reason: StaffReportReasonFilter, using authSession: AuthSession) async {
        guard selectedReason != reason || !hasLoaded else { return }
        selectedReason = reason
        hasLoaded = false
        await loadReports(using: authSession, force: true)
    }

    func reload(using authSession: AuthSession) async {
        hasLoaded = false
        await loadReports(using: authSession, force: true)
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

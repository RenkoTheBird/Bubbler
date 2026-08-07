//
//  DataExportViewModel.swift
//  BubblerApp
//

import Foundation
import Combine

struct DataExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class DataExportViewModel: ObservableObject {
    @Published private(set) var isExporting = false
    @Published var shareItem: DataExportShareItem?
    @Published var errorTitle = "Couldn't export data"
    @Published var errorMessage: String?

    /// Fetches pretty-printed JSON, writes a temp file, then presents the share sheet.
    func startExport(using authSession: AuthSession) async {
        guard !isExporting else { return }

        isExporting = true
        errorTitle = "Couldn't export data"
        errorMessage = nil
        finishSharing()

        defer { isExporting = false }

        do {
            let url = try await prepareExportFile()
            shareItem = DataExportShareItem(url: url)
        } catch is CancellationError {
            return
        } catch {
            handle(
                error,
                using: authSession,
                fallbackMessage: "We couldn't prepare your data export. Please try again."
            )
        }
    }

    /// Deletes the temp export after the share sheet dismisses.
    func finishSharing() {
        if let url = shareItem?.url {
            DataExportFileStore.removeFile(at: url)
        }
        shareItem = nil
    }

    private func prepareExportFile() async throws -> URL {
        let data = try await APIClient.exportUserData()
        return try DataExportFileStore.writeExportJSON(data)
    }

    private func handle(
        _ error: Error,
        using authSession: AuthSession,
        fallbackMessage: String
    ) {
        if case APIClientError.unauthorized = error {
            authSession.signOut()
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = description.isEmpty ? fallbackMessage : description
    }
}

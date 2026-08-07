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

enum DataExportError: Error {
    /// Zip download + temp write are not connected yet.
    case downloadNotWired
}

@MainActor
final class DataExportViewModel: ObservableObject {
    /// Flip when `prepareExportFile()` fetches zip bytes from the API.
    private static let isDownloadWired = false

    @Published private(set) var isExporting = false
    @Published var shareItem: DataExportShareItem?
    @Published var errorTitle = "Couldn't export data"
    @Published var errorMessage: String?

    /// Starts export → temp file → share. No-op until zip download is wired.
    func startExport(using authSession: AuthSession) async {
        guard !isExporting else { return }
        guard Self.isDownloadWired else { return }

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

    /// Downloads the account export zip and writes it to a temp file.
    /// Not wired yet — replace with APIClient binary fetch + `DataExportFileStore.writeExportZip`.
    private func prepareExportFile() async throws -> URL {
        throw DataExportError.downloadNotWired
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

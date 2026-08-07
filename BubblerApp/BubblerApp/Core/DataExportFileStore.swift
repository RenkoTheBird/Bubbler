//
//  DataExportFileStore.swift
//  BubblerApp
//

import Foundation

/// Temp-file helpers for account data exports (JSON). Keeps sensitive files
/// out of permanent storage and makes cleanup explicit after sharing.
enum DataExportFileStore {
    private static let directoryName = "data-exports"

    static var exportsDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    /// Writes JSON bytes to a uniquely named file under the temp exports directory.
    static func writeExportJSON(_ data: Data, createdAt: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(
            at: exportsDirectory,
            withIntermediateDirectories: true
        )

        let url = exportsDirectory.appendingPathComponent(fileName(createdAt: createdAt))
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    static func removeFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAllExports() {
        try? FileManager.default.removeItem(at: exportsDirectory)
    }

    private static func fileName(createdAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HHmmss'Z'"
        return "bubbler-export-\(formatter.string(from: createdAt)).json"
    }
}

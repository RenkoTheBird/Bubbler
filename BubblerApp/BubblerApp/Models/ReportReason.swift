import Foundation

/// Why a user is reporting another person's post.
/// Matches Phase 0 hard-removal categories plus spam / other.
enum ReportReason: String, CaseIterable, Identifiable {
    case illegalContent
    case severeViolence
    case nonConsensualSexualContent
    case harassment
    case spam
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illegalContent: "Illegal content"
        case .severeViolence: "Severe violence"
        case .nonConsensualSexualContent: "Non-consensual sexual content"
        case .harassment: "Harassment or threats"
        case .spam: "Spam"
        case .other: "Other"
        }
    }
}

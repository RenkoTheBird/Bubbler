import Foundation

/// Cap for untrusted reporter notes; matches backend `DETAILS_MAX_LENGTH`.
enum ReportDetailsLimits {
    static let maxLength = 2000
}

/// Why a user is reporting another person's post.
/// Matches Phase 0 hard-removal categories plus spam / other.
/// `illegalContent` is the severe-illegal / CSAM isolation bucket (escalation: L11).
enum ReportReason: String, CaseIterable, Identifiable {
    case illegalContent
    case severeViolence
    case nonConsensualSexualContent
    case harassment
    case spam
    case other

    var id: String { rawValue }

    /// API / DB reason string (`snake_case`).
    var apiValue: String {
        switch self {
        case .illegalContent: "illegal_content"
        case .severeViolence: "severe_violence"
        case .nonConsensualSexualContent: "non_consensual_sexual_content"
        case .harassment: "harassment"
        case .spam: "spam"
        case .other: "other"
        }
    }

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

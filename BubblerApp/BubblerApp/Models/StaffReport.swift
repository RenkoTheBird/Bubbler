import Foundation

enum StaffReportStatus: String, CaseIterable, Codable, Identifiable {
    case open
    case inReview = "in_review"
    case resolved
    case dismissed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: "Open"
        case .inReview: "In review"
        case .resolved: "Resolved"
        case .dismissed: "Dismissed"
        }
    }
}

struct StaffReport: Codable, Identifiable, Equatable {
    let id: String
    let reporterId: Int?
    let postId: String?
    let reportedUserId: Int?
    let reason: String
    let details: String?
    let status: StaffReportStatus
    let contentSnapshot: String
    let topicSnapshot: String?
    let authorUsernameSnapshot: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case postId = "post_id"
        case reportedUserId = "reported_user_id"
        case reason
        case details
        case status
        case contentSnapshot = "content_snapshot"
        case topicSnapshot = "topic_snapshot"
        case authorUsernameSnapshot = "author_username_snapshot"
        case createdAt = "created_at"
    }

    var reasonTitle: String {
        switch reason {
        case "illegal_content": "Illegal content"
        case "severe_violence": "Severe violence"
        case "non_consensual_sexual_content": "Non-consensual sexual content"
        case "harassment": "Harassment or threats"
        case "spam": "Spam"
        case "other": "Other"
        default: reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}


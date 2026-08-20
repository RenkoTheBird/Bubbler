package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

@Serializable
enum class StaffReportStatus {
    @SerialName("open")
    OPEN,

    @SerialName("in_review")
    IN_REVIEW,

    @SerialName("resolved")
    RESOLVED,

    @SerialName("dismissed")
    DISMISSED;

    val title: String
        get() = when (this) {
            OPEN -> "Open"
            IN_REVIEW -> "In review"
            RESOLVED -> "Resolved"
            DISMISSED -> "Dismissed"
        }

    val apiValue: String
        get() = when (this) {
            OPEN -> "open"
            IN_REVIEW -> "in_review"
            RESOLVED -> "resolved"
            DISMISSED -> "dismissed"
        }
}

/** Staff review ticket (`GET /admin/reports`). */
@Serializable
data class StaffReport(
    val id: String,
    @SerialName("reporter_id")
    val reporterId: Int? = null,
    @SerialName("post_id")
    val postId: String? = null,
    @SerialName("reported_user_id")
    val reportedUserId: Int? = null,
    val reason: String,
    val details: String? = null,
    val status: StaffReportStatus,
    @SerialName("content_snapshot")
    val contentSnapshot: String,
    @SerialName("topic_snapshot")
    val topicSnapshot: String? = null,
    @SerialName("author_username_snapshot")
    val authorUsernameSnapshot: String? = null,
    @SerialName("created_at")
    @Serializable(with = InstantIsoSerializer::class)
    val createdAt: Instant,
) {
    val reasonTitle: String
        get() = when (reason) {
            "illegal_content" -> "Illegal content"
            "severe_violence" -> "Severe violence"
            "non_consensual_sexual_content" -> "Non-consensual sexual content"
            "harassment" -> "Harassment or threats"
            "spam" -> "Spam"
            "other" -> "Other"
            else -> reason.replace('_', ' ').replaceFirstChar { it.uppercase() }
        }
}

@Serializable
data class StaffReportStatusUpdateBody(
    val status: String,
)

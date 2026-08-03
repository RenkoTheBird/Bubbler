package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/** Mirrors backend `Interaction` from GET /user/me interactions. */
@Serializable
data class Interaction(
    val id: String,
    @SerialName("user_id")
    val userId: String,
    @SerialName("post_id")
    val postId: String,
    val type: GraphInteractionType,
    @SerialName("created_at")
    @Serializable(with = InstantIsoSerializer::class)
    val createdAt: Instant,
    val topic: String,
    @SerialName("view_time")
    val viewTime: Double,
    val liked: Boolean,
) {
    /** Short copy for the profile Bubble Trail row. */
    val trailSummary: String
        get() {
            val trimmed = topic.trim()
            val topicLabel = if (trimmed.isEmpty()) {
                "a post"
            } else {
                "a ${KnownTopics.displayName(trimmed)} post"
            }
            return when (type) {
                GraphInteractionType.LIKE -> "Liked $topicLabel"
                GraphInteractionType.SKIP -> "Skipped $topicLabel"
                GraphInteractionType.EXPLORE -> "Explored $topicLabel"
            }
        }
}

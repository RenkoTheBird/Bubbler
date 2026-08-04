package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Client-side graph walk node wrapping a [Post] with preference flags.
 * Not an API payload — built in [com.bubbler.android.features.graph] ViewModels.
 */
data class GraphFeedNode(
    val post: Post,
    val isPreferredTopic: Boolean = false,
    val isBlacklistedTopic: Boolean = false,
) {
    val id: String get() = post.id

    val topicName: String?
        get() {
            val topic = post.topic?.trim().orEmpty()
            return topic.ifEmpty { null }
        }
}

@Serializable
data class GraphSessionFeed(
    val posts: List<Post>,
    @SerialName("seed_strategy")
    val seedStrategy: String,
    val diversify: Boolean,
) {
    val statusLabel: String
        get() = when (seedStrategy) {
            "diversify", "diversify_fallback" -> "Exploring across topics"
            "soft_prior", "soft_prior_fallback" -> "Seeded from recent interests"
            "random" -> "Random topic mix"
            else -> "Graph session ready"
        }
}

@Serializable
enum class GraphInteractionType {
    @SerialName("like")
    LIKE,

    @SerialName("skip")
    SKIP,

    @SerialName("explore")
    EXPLORE,
}

@Serializable
data class GraphInteractionPayload(
    @SerialName("post_id")
    val postId: String,
    val type: GraphInteractionType,
    @SerialName("view_time")
    val viewTime: Double = 0.0,
)

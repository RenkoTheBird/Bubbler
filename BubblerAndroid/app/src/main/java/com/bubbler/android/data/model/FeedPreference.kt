package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Per-post feed preference scale (-2..2). Zero means neutral (no stored preference). */
enum class FeedPreference(val rawValue: Int) {
    MUCH_LESS(-2),
    LESS(-1),
    NEUTRAL(0),
    MORE(1),
    MUCH_MORE(2),
    ;

    val label: String
        get() = when (this) {
            MUCH_LESS -> "Show a lot less like this"
            LESS -> "Show less like this"
            NEUTRAL -> "Neutral"
            MORE -> "Show more like this"
            MUCH_MORE -> "Show a lot more like this"
        }

    val shortLabel: String
        get() = when (this) {
            MUCH_LESS -> "Much less"
            LESS -> "Less"
            NEUTRAL -> "Neutral"
            MORE -> "More"
            MUCH_MORE -> "Much more"
        }

    companion object {
        fun fromRaw(value: Int): FeedPreference =
            entries.firstOrNull { it.rawValue == value } ?: NEUTRAL
    }
}

@Serializable
data class FeedPreferenceEntry(
    @SerialName("post_id")
    val postId: String,
    @SerialName("feed_preference")
    val feedPreference: Int,
)

@Serializable
data class FeedPreferenceUpdateBody(
    @SerialName("feed_preference")
    val feedPreference: Int,
)

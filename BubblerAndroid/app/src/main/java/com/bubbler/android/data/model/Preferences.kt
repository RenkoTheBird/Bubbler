package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

@Serializable
enum class FeedPreset {
    @SerialName("stay_in_lane")
    STAY_IN_LANE,

    @SerialName("cross_pollinate")
    CROSS_POLLINATE,

    @SerialName("wild_walk")
    WILD_WALK,

    @SerialName("custom")
    CUSTOM,
}

enum class CompositionTier {
    TOPIC,
    POST,
}

@Serializable
enum class PreferenceType {
    @SerialName("preferred")
    PREFERRED,

    @SerialName("blacklisted")
    BLACKLISTED,
}

@Serializable
data class TopicPreference(
    val topic: String,
    @SerialName("preference_type")
    val preferenceType: PreferenceType,
)

@Serializable
data class CompositionWeights(
    val similar: Double = DEFAULT.similar,
    val opposite: Double = DEFAULT.opposite,
    val surprise: Double = DEFAULT.surprise,
) {
    val total: Double get() = similar + opposite + surprise

    fun normalized(): CompositionWeights {
        val clamped = CompositionWeights(
            similar = similar.clamped(0.0, 1.0),
            opposite = opposite.clamped(0.0, 1.0),
            surprise = surprise.clamped(0.0, 1.0),
        )
        val sum = clamped.total
        if (sum <= 0.0) return DEFAULT
        return CompositionWeights(
            similar = clamped.similar / sum,
            opposite = clamped.opposite / sum,
            surprise = clamped.surprise / sum,
        )
    }

    companion object {
        val DEFAULT = CompositionWeights(
            similar = 0.55,
            opposite = 0.15,
            surprise = 0.30,
        )

        private const val MATCH_EPSILON = 0.02

        fun presetWeights(preset: FeedPreset, tier: CompositionTier): CompositionWeights =
            when (preset) {
                FeedPreset.STAY_IN_LANE -> DEFAULT
                FeedPreset.CROSS_POLLINATE -> if (tier == CompositionTier.TOPIC) {
                    CompositionWeights(similar = 0.15, opposite = 0.55, surprise = 0.30)
                } else {
                    CompositionWeights(similar = 0.55, opposite = 0.15, surprise = 0.30)
                }
                FeedPreset.WILD_WALK -> CompositionWeights(
                    similar = 0.15,
                    opposite = 0.25,
                    surprise = 0.60,
                )
                FeedPreset.CUSTOM -> DEFAULT
            }

        fun matches(left: CompositionWeights, right: CompositionWeights): Boolean {
            val a = left.normalized()
            val b = right.normalized()
            return abs(a.similar - b.similar) <= MATCH_EPSILON &&
                abs(a.opposite - b.opposite) <= MATCH_EPSILON &&
                abs(a.surprise - b.surprise) <= MATCH_EPSILON
        }
    }
}

@Serializable
data class UserPreferences(
    @SerialName("user_id")
    val userId: Int,
    @SerialName("feed_preset")
    val feedPreset: FeedPreset = FeedPreset.STAY_IN_LANE,
    @SerialName("topic_composition")
    val topicComposition: CompositionWeights = CompositionWeights.presetWeights(
        FeedPreset.STAY_IN_LANE,
        CompositionTier.TOPIC,
    ),
    @SerialName("post_composition")
    val postComposition: CompositionWeights = CompositionWeights.presetWeights(
        FeedPreset.STAY_IN_LANE,
        CompositionTier.POST,
    ),
    @SerialName("topic_preferences")
    val topicPreferences: List<TopicPreference> = emptyList(),
    @SerialName("use_view_time")
    val useViewTime: Boolean = false,
    @SerialName("view_time_weight")
    val viewTimeWeight: Double = 0.1,
    @SerialName("use_recency")
    val useRecency: Boolean = false,
    @SerialName("ai_topic_detection")
    val aiTopicDetection: Boolean = false,
) {
    val preferredTopics: List<String>
        get() = topicPreferences
            .filter { it.preferenceType == PreferenceType.PREFERRED }
            .map { it.topic }

    val blacklistedTopics: List<String>
        get() = topicPreferences
            .filter { it.preferenceType == PreferenceType.BLACKLISTED }
            .map { it.topic }

    val updatePayload: PreferencesUpdatePayload
        get() = PreferencesUpdatePayload(
            feedPreset = feedPreset,
            topicComposition = topicComposition,
            postComposition = postComposition,
            topicPreferences = topicPreferences,
            useViewTime = useViewTime,
            viewTimeWeight = viewTimeWeight,
            useRecency = useRecency,
            aiTopicDetection = aiTopicDetection,
        )

    fun applyPreset(preset: FeedPreset): UserPreferences {
        if (preset == FeedPreset.CUSTOM) {
            return copy(feedPreset = FeedPreset.CUSTOM)
        }
        return copy(
            feedPreset = preset,
            topicComposition = CompositionWeights.presetWeights(preset, CompositionTier.TOPIC),
            postComposition = CompositionWeights.presetWeights(preset, CompositionTier.POST),
        )
    }

    fun detectPreset(): UserPreferences {
        for (preset in SELECTABLE_PRESETS) {
            val topic = CompositionWeights.presetWeights(preset, CompositionTier.TOPIC)
            val post = CompositionWeights.presetWeights(preset, CompositionTier.POST)
            if (CompositionWeights.matches(topicComposition, topic) &&
                CompositionWeights.matches(postComposition, post)
            ) {
                return copy(feedPreset = preset)
            }
        }
        return copy(feedPreset = FeedPreset.CUSTOM)
    }

    fun updatePreferredTopics(topics: List<String>): UserPreferences {
        val preferred = TopicPreferenceList.cleaned(topics).map {
            TopicPreference(it, PreferenceType.PREFERRED)
        }
        val preferredKeys = preferred.map { it.topic.lowercase() }.toSet()
        val blacklisted = topicPreferences.filter {
            it.preferenceType == PreferenceType.BLACKLISTED &&
                it.topic.lowercase() !in preferredKeys
        }
        return copy(topicPreferences = mergeTopicPreferences(preferred, blacklisted))
    }

    fun updateBlacklistedTopics(topics: List<String>): UserPreferences {
        val blacklisted = TopicPreferenceList.cleaned(topics).map {
            TopicPreference(it, PreferenceType.BLACKLISTED)
        }
        val blacklistedKeys = blacklisted.map { it.topic.lowercase() }.toSet()
        val preferred = topicPreferences.filter {
            it.preferenceType == PreferenceType.PREFERRED &&
                it.topic.lowercase() !in blacklistedKeys
        }
        return copy(topicPreferences = mergeTopicPreferences(preferred, blacklisted))
    }

    fun preferTopic(topic: String): UserPreferences {
        val withPreferred = updatePreferredTopics(
            TopicPreferenceList.add(topic, to = preferredTopics),
        )
        return withPreferred.updateBlacklistedTopics(
            TopicPreferenceList.remove(topic, from = withPreferred.blacklistedTopics),
        )
    }

    fun unpreferTopic(topic: String): UserPreferences =
        updatePreferredTopics(TopicPreferenceList.remove(topic, from = preferredTopics))

    fun blacklistTopic(topic: String): UserPreferences {
        val withoutPreferred = updatePreferredTopics(
            TopicPreferenceList.remove(topic, from = preferredTopics),
        )
        return withoutPreferred.updateBlacklistedTopics(
            TopicPreferenceList.add(topic, to = withoutPreferred.blacklistedTopics),
        )
    }

    fun unblacklistTopic(topic: String): UserPreferences =
        updateBlacklistedTopics(TopicPreferenceList.remove(topic, from = blacklistedTopics))

    fun sanitized(): UserPreferences {
        val preferred = TopicPreferenceList.cleaned(preferredTopics)
        val blacklist = TopicPreferenceList.cleaned(blacklistedTopics)
            .filter { blacklistedTopic ->
                preferred.none { it.equals(blacklistedTopic, ignoreCase = true) }
            }

        var result = UserPreferences(
            userId = userId,
            feedPreset = feedPreset,
            topicComposition = topicComposition.normalized(),
            postComposition = postComposition.normalized(),
            topicPreferences = mergeTopicPreferences(
                preferred = preferred.map { TopicPreference(it, PreferenceType.PREFERRED) },
                blacklisted = blacklist.map { TopicPreference(it, PreferenceType.BLACKLISTED) },
            ),
            useViewTime = useViewTime,
            viewTimeWeight = viewTimeWeight.clamped(0.0, 1.0),
            useRecency = useRecency,
            aiTopicDetection = aiTopicDetection,
        )
        result = if (result.feedPreset != FeedPreset.CUSTOM) {
            result.applyPreset(result.feedPreset)
        } else {
            result.detectPreset()
        }
        return result
    }

    companion object {
        val PLACEHOLDER: UserPreferences = systemDefaults(userId = 0)

        val SELECTABLE_PRESETS: List<FeedPreset> = listOf(
            FeedPreset.STAY_IN_LANE,
            FeedPreset.CROSS_POLLINATE,
            FeedPreset.WILD_WALK,
        )

        fun systemDefaults(userId: Int): UserPreferences = UserPreferences(
            userId = userId,
            feedPreset = FeedPreset.STAY_IN_LANE,
            topicComposition = CompositionWeights.presetWeights(
                FeedPreset.STAY_IN_LANE,
                CompositionTier.TOPIC,
            ),
            postComposition = CompositionWeights.presetWeights(
                FeedPreset.STAY_IN_LANE,
                CompositionTier.POST,
            ),
            topicPreferences = emptyList(),
            useViewTime = false,
            viewTimeWeight = 0.1,
            useRecency = false,
            aiTopicDetection = false,
        )

        private fun mergeTopicPreferences(
            preferred: List<TopicPreference>,
            blacklisted: List<TopicPreference>,
        ): List<TopicPreference> {
            val seen = mutableSetOf<String>()
            val merged = mutableListOf<TopicPreference>()
            for (pref in preferred + blacklisted) {
                val key = pref.topic.lowercase()
                if (seen.add(key)) {
                    merged.add(pref)
                }
            }
            return merged.sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.topic })
        }
    }
}

@Serializable
data class PreferencesUpdatePayload(
    @SerialName("feed_preset")
    val feedPreset: FeedPreset = FeedPreset.STAY_IN_LANE,
    @SerialName("topic_composition")
    val topicComposition: CompositionWeights = CompositionWeights.DEFAULT,
    @SerialName("post_composition")
    val postComposition: CompositionWeights = CompositionWeights.DEFAULT,
    @SerialName("topic_preferences")
    val topicPreferences: List<TopicPreference>,
    @SerialName("use_view_time")
    val useViewTime: Boolean = false,
    @SerialName("view_time_weight")
    val viewTimeWeight: Double = 0.1,
    @SerialName("use_recency")
    val useRecency: Boolean = false,
    @SerialName("ai_topic_detection")
    val aiTopicDetection: Boolean = false,
)

fun FeedPreset.displayTitle(): String = when (this) {
    FeedPreset.STAY_IN_LANE -> "Stay in lane"
    FeedPreset.CROSS_POLLINATE -> "Cross-pollinate"
    FeedPreset.WILD_WALK -> "Wild walk"
    FeedPreset.CUSTOM -> "Custom"
}

fun FeedPreset.displayDescription(): String = when (this) {
    FeedPreset.STAY_IN_LANE ->
        "Keep exploring within familiar topics and closely related posts."
    FeedPreset.CROSS_POLLINATE ->
        "Jump to different topics while surfacing posts that still feel connected to what you're reading."
    FeedPreset.WILD_WALK ->
        "Maximize variety with unexpected topics and posts."
    FeedPreset.CUSTOM ->
        "Your manually tuned topic and post mix (set in Advanced)."
}

private fun Double.clamped(min: Double, max: Double): Double = min(max(this, min), max)

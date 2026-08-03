package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.math.max
import kotlin.math.min

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
data class FeedStrategyWeights(
    val similar: Double = DEFAULT.similar,
    val graph: Double = DEFAULT.graph,
    val opposite: Double = DEFAULT.opposite,
    val random: Double = DEFAULT.random,
) {
    val total: Double get() = similar + graph + opposite + random

    fun normalized(): FeedStrategyWeights {
        val clamped = FeedStrategyWeights(
            similar = similar.clamped(0.0, 1.0),
            graph = graph.clamped(0.0, 1.0),
            opposite = opposite.clamped(0.0, 1.0),
            random = random.clamped(0.0, 1.0),
        )
        val sum = clamped.total
        if (sum <= 0.0) return DEFAULT
        return FeedStrategyWeights(
            similar = clamped.similar / sum,
            graph = clamped.graph / sum,
            opposite = clamped.opposite / sum,
            random = clamped.random / sum,
        )
    }

    companion object {
        val DEFAULT = FeedStrategyWeights(
            similar = 0.4,
            graph = 0.25,
            opposite = 0.2,
            random = 0.15,
        )
    }
}

@Serializable
data class UserPreferences(
    @SerialName("user_id")
    val userId: Int,
    @SerialName("diversity_tolerance")
    val diversityTolerance: Double,
    val randomness: Double,
    @SerialName("topic_preferences")
    val topicPreferences: List<TopicPreference> = emptyList(),
    @SerialName("use_view_time")
    val useViewTime: Boolean = false,
    @SerialName("view_time_weight")
    val viewTimeWeight: Double = 0.1,
    @SerialName("use_recency")
    val useRecency: Boolean = true,
    @SerialName("ai_topic_detection")
    val aiTopicDetection: Boolean = false,
    @SerialName("strategy_weights")
    val strategyWeights: FeedStrategyWeights = FeedStrategyWeights.DEFAULT,
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
            diversityTolerance = diversityTolerance,
            randomness = randomness,
            topicPreferences = topicPreferences,
            useViewTime = useViewTime,
            viewTimeWeight = viewTimeWeight,
            useRecency = useRecency,
            aiTopicDetection = aiTopicDetection,
            strategyWeights = strategyWeights,
        )

    fun updatePreferredTopics(topics: List<String>): UserPreferences {
        val preferred = TopicPreferenceList.cleaned(topics).map {
            TopicPreference(it, PreferenceType.PREFERRED)
        }
        val preferredKeys = preferred.map { it.topic.lowercase() }.toSet()
        // Preferring a topic must clear any blacklist entry in the same update.
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
        // Blacklisting a topic must clear any preferred entry in the same update.
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

        return UserPreferences(
            userId = userId,
            diversityTolerance = diversityTolerance.clamped(0.0, 1.0),
            randomness = randomness.clamped(0.0, 1.0),
            topicPreferences = mergeTopicPreferences(
                preferred = preferred.map { TopicPreference(it, PreferenceType.PREFERRED) },
                blacklisted = blacklist.map { TopicPreference(it, PreferenceType.BLACKLISTED) },
            ),
            useViewTime = useViewTime,
            viewTimeWeight = viewTimeWeight.clamped(0.0, 1.0),
            useRecency = useRecency,
            aiTopicDetection = aiTopicDetection,
            strategyWeights = strategyWeights.normalized(),
        )
    }

    companion object {
        val PLACEHOLDER: UserPreferences = systemDefaults(userId = 0)

        /** Built-in algorithm defaults (matches backend `default_user_prefs`). */
        fun systemDefaults(userId: Int): UserPreferences = UserPreferences(
            userId = userId,
            diversityTolerance = 0.4,
            randomness = 0.4,
            topicPreferences = emptyList(),
            useViewTime = false,
            viewTimeWeight = 0.1,
            useRecency = true,
            aiTopicDetection = false,
            strategyWeights = FeedStrategyWeights.DEFAULT,
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
    @SerialName("diversity_tolerance")
    val diversityTolerance: Double,
    val randomness: Double,
    @SerialName("topic_preferences")
    val topicPreferences: List<TopicPreference>,
    @SerialName("use_view_time")
    val useViewTime: Boolean = false,
    @SerialName("view_time_weight")
    val viewTimeWeight: Double = 0.1,
    @SerialName("use_recency")
    val useRecency: Boolean = true,
    @SerialName("ai_topic_detection")
    val aiTopicDetection: Boolean = false,
    @SerialName("strategy_weights")
    val strategyWeights: FeedStrategyWeights = FeedStrategyWeights.DEFAULT,
)

private fun Double.clamped(min: Double, max: Double): Double = min(max(this, min), max)

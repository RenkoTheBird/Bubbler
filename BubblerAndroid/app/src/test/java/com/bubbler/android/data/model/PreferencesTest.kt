package com.bubbler.android.data.model

import com.bubbler.android.core.network.ApiClient
import kotlinx.serialization.encodeToString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PreferencesTest {
    private val json = ApiClient.defaultJson()

    @Test
    fun decodesUserPreferences() {
        val prefs = json.decodeFromString<UserPreferences>(
            """
            {
              "user_id": 7,
              "diversity_tolerance": 0.4,
              "randomness": 0.35,
              "topic_preferences": [
                {"topic": "technology", "preference_type": "preferred"},
                {"topic": "politics", "preference_type": "blacklisted"}
              ],
              "use_view_time": true,
              "view_time_weight": 0.2,
              "use_recency": false,
              "ai_topic_detection": false,
              "strategy_weights": {
                "similar": 0.5,
                "graph": 0.2,
                "opposite": 0.2,
                "random": 0.1
              }
            }
            """.trimIndent(),
        )

        assertEquals(7, prefs.userId)
        assertEquals(0.4, prefs.diversityTolerance, 0.0)
        assertEquals(0.35, prefs.randomness, 0.0)
        assertEquals(listOf("technology"), prefs.preferredTopics)
        assertEquals(listOf("politics"), prefs.blacklistedTopics)
        assertTrue(prefs.useViewTime)
        assertEquals(0.2, prefs.viewTimeWeight, 0.0)
        assertFalse(prefs.useRecency)
        assertEquals(0.5, prefs.strategyWeights.similar, 0.0)
    }

    @Test
    fun strategyWeights_fillMissingKeysWithDefaults() {
        val prefs = json.decodeFromString<UserPreferences>(
            """
            {
              "user_id": 1,
              "diversity_tolerance": 0.4,
              "randomness": 0.4,
              "topic_preferences": [],
              "strategy_weights": { "similar": 0.9 }
            }
            """.trimIndent(),
        )

        assertEquals(0.9, prefs.strategyWeights.similar, 0.0)
        assertEquals(FeedStrategyWeights.DEFAULT.graph, prefs.strategyWeights.graph, 0.0)
        assertEquals(FeedStrategyWeights.DEFAULT.opposite, prefs.strategyWeights.opposite, 0.0)
        assertEquals(FeedStrategyWeights.DEFAULT.random, prefs.strategyWeights.random, 0.0)
    }

    @Test
    fun preferTopic_clearsBlacklistConflict() {
        val start = UserPreferences.systemDefaults(1)
            .blacklistTopic("technology")
        val preferred = start.preferTopic("technology")

        assertEquals(listOf("technology"), preferred.preferredTopics)
        assertTrue(preferred.blacklistedTopics.none { it.equals("technology", ignoreCase = true) })
    }

    @Test
    fun blacklistTopic_clearsPreferredConflict() {
        val start = UserPreferences.systemDefaults(1)
            .preferTopic("science")
        val blacklisted = start.blacklistTopic("science")

        assertEquals(listOf("science"), blacklisted.blacklistedTopics)
        assertTrue(blacklisted.preferredTopics.none { it.equals("science", ignoreCase = true) })
    }

    @Test
    fun sanitized_clampsAndNormalizesWeights() {
        val messy = UserPreferences(
            userId = 3,
            diversityTolerance = 1.5,
            randomness = -0.2,
            topicPreferences = listOf(
                TopicPreference("Technology", PreferenceType.PREFERRED),
                TopicPreference("technology", PreferenceType.BLACKLISTED),
                TopicPreference("Sports", PreferenceType.PREFERRED),
            ),
            viewTimeWeight = 2.0,
            strategyWeights = FeedStrategyWeights(
                similar = 2.0,
                graph = 2.0,
                opposite = 0.0,
                random = 0.0,
            ),
        ).sanitized()

        assertEquals(1.0, messy.diversityTolerance, 0.0)
        assertEquals(0.0, messy.randomness, 0.0)
        assertEquals(1.0, messy.viewTimeWeight, 0.0)
        assertEquals(listOf("Sports", "Technology"), messy.preferredTopics)
        assertTrue(messy.blacklistedTopics.isEmpty())
        assertEquals(0.5, messy.strategyWeights.similar, 1e-9)
        assertEquals(0.5, messy.strategyWeights.graph, 1e-9)
        assertEquals(1.0, messy.strategyWeights.total, 1e-9)
    }

    @Test
    fun updatePayload_roundTripsThroughJson() {
        val prefs = UserPreferences.systemDefaults(5)
            .preferTopic("health")
            .sanitized()
        val encoded = json.encodeToString(prefs.updatePayload)
        val decoded = json.decodeFromString<PreferencesUpdatePayload>(encoded)

        assertEquals(prefs.diversityTolerance, decoded.diversityTolerance, 0.0)
        assertEquals(prefs.preferredTopics, decoded.topicPreferences.map { it.topic })
        assertEquals(prefs.strategyWeights, decoded.strategyWeights)
    }
}

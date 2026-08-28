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
              "feed_preset": "stay_in_lane",
              "topic_composition": {
                "similar": 0.55,
                "opposite": 0.15,
                "surprise": 0.30
              },
              "post_composition": {
                "similar": 0.55,
                "opposite": 0.15,
                "surprise": 0.30
              },
              "topic_preferences": [
                {"topic": "technology", "preference_type": "preferred"},
                {"topic": "politics", "preference_type": "blacklisted"}
              ],
              "use_view_time": true,
              "view_time_weight": 0.2,
              "use_recency": false,
              "ai_topic_detection": false
            }
            """.trimIndent(),
        )

        assertEquals(7, prefs.userId)
        assertEquals(FeedPreset.STAY_IN_LANE, prefs.feedPreset)
        assertEquals(0.55, prefs.topicComposition.similar, 0.0)
        assertEquals(listOf("technology"), prefs.preferredTopics)
        assertEquals(listOf("politics"), prefs.blacklistedTopics)
        assertTrue(prefs.useViewTime)
        assertEquals(0.2, prefs.viewTimeWeight, 0.0)
        assertFalse(prefs.useRecency)
    }

    @Test
    fun systemDefaults_matchConservativeLaunchPolicy() {
        val prefs = UserPreferences.systemDefaults(userId = 1)

        assertEquals(FeedPreset.STAY_IN_LANE, prefs.feedPreset)
        assertTrue(prefs.topicPreferences.isEmpty())
        assertFalse(prefs.useViewTime)
        assertFalse(prefs.useRecency)
        assertFalse(prefs.aiTopicDetection)
    }

    @Test
    fun applyPreset_setsCompositionWeights() {
        val prefs = UserPreferences.systemDefaults(1)
            .applyPreset(FeedPreset.WILD_WALK)

        assertEquals(FeedPreset.WILD_WALK, prefs.feedPreset)
        assertEquals(0.60, prefs.topicComposition.surprise, 0.0)
        assertEquals(0.60, prefs.postComposition.surprise, 0.0)
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
            feedPreset = FeedPreset.CUSTOM,
            topicComposition = CompositionWeights(similar = 2.0, opposite = 2.0, surprise = 0.0),
            postComposition = CompositionWeights(similar = 2.0, opposite = 0.0, surprise = 0.0),
            topicPreferences = listOf(
                TopicPreference("Technology", PreferenceType.PREFERRED),
                TopicPreference("technology", PreferenceType.BLACKLISTED),
                TopicPreference("Sports", PreferenceType.PREFERRED),
            ),
            viewTimeWeight = 2.0,
        ).sanitized()

        assertEquals(1.0, messy.viewTimeWeight, 0.0)
        assertEquals(listOf("Sports", "Technology"), messy.preferredTopics)
        assertTrue(messy.blacklistedTopics.isEmpty())
        assertEquals(0.5, messy.topicComposition.similar, 1e-9)
        assertEquals(0.5, messy.postComposition.similar, 1e-9)
        assertEquals(1.0, messy.topicComposition.total, 1e-9)
    }

    @Test
    fun updatePayload_roundTripsThroughJson() {
        val prefs = UserPreferences.systemDefaults(5)
            .preferTopic("health")
            .sanitized()
        val encoded = json.encodeToString(prefs.updatePayload)
        val decoded = json.decodeFromString<PreferencesUpdatePayload>(encoded)

        assertEquals(prefs.feedPreset, decoded.feedPreset)
        assertEquals(prefs.preferredTopics, decoded.topicPreferences.map { it.topic })
        assertEquals(prefs.topicComposition, decoded.topicComposition)
        assertEquals(prefs.postComposition, decoded.postComposition)
    }
}

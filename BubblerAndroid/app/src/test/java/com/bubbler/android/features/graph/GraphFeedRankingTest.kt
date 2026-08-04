package com.bubbler.android.features.graph

import com.bubbler.android.data.model.Post
import com.bubbler.android.data.model.PreferenceType
import com.bubbler.android.data.model.TopicPreference
import com.bubbler.android.data.model.UserPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class GraphFeedRankingTest {
    @Test
    fun rankedNodes_prefersPreferredTopics_whilePreservingRelativeOrder() {
        val preferences = UserPreferences.systemDefaults(userId = 1).copy(
            topicPreferences = listOf(
                TopicPreference("sports", PreferenceType.PREFERRED),
            ),
        )
        val posts = listOf(
            post("1", "technology"),
            post("2", "sports"),
            post("3", "science"),
            post("4", "sports"),
        )

        val ranked = GraphFeedRanking.rankedNodes(posts, preferences)
        assertEquals(listOf("2", "4", "1", "3"), ranked.map { it.id })
        assertTrue(ranked[0].isPreferredTopic)
        assertTrue(ranked[1].isPreferredTopic)
        assertFalse(ranked[2].isPreferredTopic)
    }

    @Test
    fun rankedNodes_dedupesById() {
        val posts = listOf(
            post("1", "technology"),
            post("1", "technology"),
            post("2", "sports"),
        )
        val ranked = GraphFeedRanking.rankedNodes(posts, UserPreferences.PLACEHOLDER)
        assertEquals(listOf("1", "2"), ranked.map { it.id })
    }

    @Test
    fun makeNode_marksPreferredAndBlacklisted() {
        val preferences = UserPreferences.systemDefaults(userId = 1).copy(
            topicPreferences = listOf(
                TopicPreference("Sports", PreferenceType.PREFERRED),
                TopicPreference("Politics", PreferenceType.BLACKLISTED),
            ),
        )

        val preferred = GraphFeedRanking.makeNode(post("1", "sports"), preferences)
        assertTrue(preferred.isPreferredTopic)
        assertFalse(preferred.isBlacklistedTopic)

        val blacklisted = GraphFeedRanking.makeNode(post("2", "politics"), preferences)
        assertFalse(blacklisted.isPreferredTopic)
        assertTrue(blacklisted.isBlacklistedTopic)
    }

    @Test
    fun statusMessage_joinsPreferredAndSeed() {
        val node = GraphFeedRanking.makeNode(
            post("1", "sports"),
            UserPreferences.systemDefaults(userId = 1).copy(
                topicPreferences = listOf(
                    TopicPreference("sports", PreferenceType.PREFERRED),
                ),
            ),
        )
        assertEquals(
            "Preferred: sports · Exploring across topics",
            GraphFeedRanking.statusMessage(
                node = node,
                seedStrategyLabel = "Exploring across topics",
                defaultMessage = "Session ready.",
            ),
        )
    }

    private fun post(id: String, topic: String): Post = Post(
        id = id,
        userId = 1,
        username = "u$id",
        content = "content $id",
        createdAt = Instant.parse("2026-01-01T00:00:00Z"),
        topic = topic,
    )
}

package com.bubbler.android.data.model

import com.bubbler.android.core.network.ApiClient
import kotlinx.serialization.encodeToString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class GraphTest {
    private val json = ApiClient.defaultJson()

    @Test
    fun decodesSessionFeed() {
        val feed = json.decodeFromString<GraphSessionFeed>(
            """
            {
              "posts": [
                {
                  "id": "p1",
                  "user_id": 2,
                  "username": "neighbor",
                  "content": "seed",
                  "created_at": "2024-01-01T00:00:00Z",
                  "topic": "science"
                }
              ],
              "seed_strategy": "soft_prior",
              "diversify": false
            }
            """.trimIndent(),
        )

        assertEquals(1, feed.posts.size)
        assertEquals("p1", feed.posts[0].id)
        assertEquals("soft_prior", feed.seedStrategy)
        assertFalse(feed.diversify)
        assertEquals("Seeded from recent interests", feed.statusLabel)
    }

    @Test
    fun statusLabel_coversKnownStrategies() {
        assertEquals(
            "Exploring across topics",
            GraphSessionFeed(emptyList(), "diversify", true).statusLabel,
        )
        assertEquals(
            "Exploring across topics",
            GraphSessionFeed(emptyList(), "diversify_fallback", true).statusLabel,
        )
        assertEquals(
            "Random topic mix",
            GraphSessionFeed(emptyList(), "random", false).statusLabel,
        )
        assertEquals(
            "Graph session ready",
            GraphSessionFeed(emptyList(), "unknown", false).statusLabel,
        )
    }

    @Test
    fun encodesAndDecodesInteractionPayload() {
        val payload = GraphInteractionPayload(
            postId = "post-9",
            type = GraphInteractionType.EXPLORE,
            viewTime = 1.5,
        )
        val encoded = json.encodeToString(payload)
        assertTrue(encoded.contains("\"post_id\""))
        assertTrue(encoded.contains("\"explore\""))
        assertTrue(encoded.contains("\"view_time\""))

        val decoded = json.decodeFromString<GraphInteractionPayload>(encoded)
        assertEquals(payload, decoded)
    }

    @Test
    fun graphFeedNode_exposesPostFieldsAndTopic() {
        val post = Post(
            id = "n1",
            userId = 3,
            username = "a",
            content = "body",
            createdAt = Instant.parse("2024-01-01T00:00:00Z"),
            topic = "  sports  ",
        )
        val node = GraphFeedNode(
            post = post,
            isPreferredTopic = true,
            isBlacklistedTopic = false,
        )

        assertEquals("n1", node.id)
        assertEquals("body", node.content)
        assertEquals(3, node.userId)
        assertEquals("sports", node.topicName)
        assertTrue(node.isPreferredTopic)
        assertFalse(node.isBlacklistedTopic)
    }

    @Test
    fun graphFeedNode_blankTopicBecomesNull() {
        val post = Post(
            id = "n2",
            userId = 1,
            content = "x",
            createdAt = Instant.parse("2024-01-01T00:00:00Z"),
            topic = "   ",
        )
        assertEquals(null, GraphFeedNode(post).topicName)
    }
}

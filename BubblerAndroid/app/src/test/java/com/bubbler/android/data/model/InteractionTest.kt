package com.bubbler.android.data.model

import com.bubbler.android.core.network.ApiClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class InteractionTest {
    private val json = ApiClient.defaultJson()

    @Test
    fun decodesInteraction() {
        val interaction = json.decodeFromString<Interaction>(
            """
            {
              "id": "int-1",
              "user_id": "7",
              "post_id": "post-1",
              "type": "like",
              "created_at": "2024-06-15T12:30:45Z",
              "topic": "technology",
              "view_time": 2.5,
              "liked": true
            }
            """.trimIndent(),
        )

        assertEquals("int-1", interaction.id)
        assertEquals("7", interaction.userId)
        assertEquals("post-1", interaction.postId)
        assertEquals(GraphInteractionType.LIKE, interaction.type)
        assertEquals(Instant.parse("2024-06-15T12:30:45Z"), interaction.createdAt)
        assertEquals("technology", interaction.topic)
        assertEquals(2.5, interaction.viewTime, 0.0)
        assertTrue(interaction.liked)
        assertEquals("Liked a Technology post", interaction.trailSummary)
    }

    @Test
    fun trailSummary_emptyTopicUsesGenericLabel() {
        val interaction = Interaction(
            id = "i",
            userId = "1",
            postId = "p",
            type = GraphInteractionType.SKIP,
            createdAt = Instant.parse("2024-01-01T00:00:00Z"),
            topic = "  ",
            viewTime = 0.0,
            liked = false,
        )
        assertEquals("Skipped a post", interaction.trailSummary)
        assertFalse(interaction.liked)
    }

    @Test
    fun trailSummary_explore() {
        val interaction = Interaction(
            id = "i",
            userId = "1",
            postId = "p",
            type = GraphInteractionType.EXPLORE,
            createdAt = Instant.parse("2024-01-01T00:00:00Z"),
            topic = "science",
            viewTime = 0.0,
            liked = false,
        )
        assertEquals("Explored a Science post", interaction.trailSummary)
    }
}

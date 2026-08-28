package com.bubbler.android.data.model

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant

class InteractionTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun decodesPreferenceInteraction() {
        val interaction = json.decodeFromString<Interaction>(
            """
            {
              "id": "int-1",
              "user_id": "7",
              "post_id": "post-1",
              "type": "preference",
              "created_at": "2024-06-15T12:30:45Z",
              "topic": "technology",
              "view_time": 2.5,
              "feed_preference": 2
            }
            """.trimIndent(),
        )

        assertEquals("int-1", interaction.id)
        assertEquals("7", interaction.userId)
        assertEquals("post-1", interaction.postId)
        assertEquals(GraphInteractionType.PREFERENCE, interaction.type)
        assertEquals(Instant.parse("2024-06-15T12:30:45Z"), interaction.createdAt)
        assertEquals("technology", interaction.topic)
        assertEquals(2.5, interaction.viewTime, 0.0)
        assertEquals(2, interaction.feedPreference)
        assertEquals("Much more for a Technology post", interaction.trailSummary)
    }

    @Test
    fun skipTrailSummaryWithoutTopic() {
        val interaction = Interaction(
            id = "1",
            userId = "1",
            postId = "p1",
            type = GraphInteractionType.SKIP,
            createdAt = Instant.parse("2024-06-15T12:30:45Z"),
            topic = "",
            viewTime = 0.0,
            feedPreference = null,
        )
        assertEquals("Skipped a post", interaction.trailSummary)
    }

    @Test
    fun exploreTrailSummaryUsesTopicDisplayName() {
        val interaction = Interaction(
            id = "1",
            userId = "1",
            postId = "p1",
            type = GraphInteractionType.EXPLORE,
            createdAt = Instant.parse("2024-06-15T12:30:45Z"),
            topic = "science",
            viewTime = 0.0,
            feedPreference = null,
        )
        assertEquals("Explored a Science post", interaction.trailSummary)
        assertNull(interaction.feedPreference)
    }
}

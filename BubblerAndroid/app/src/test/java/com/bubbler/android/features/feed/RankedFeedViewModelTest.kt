package com.bubbler.android.features.feed

import com.bubbler.android.data.model.Post
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class RankedFeedViewModelTest {
    private val now: Instant = Instant.parse("2026-08-03T12:00:00Z")

    @Test
    fun prioritize_withNullTopic_preservesOrder() {
        val posts = listOf(post("a", "sports"), post("b", "technology"), post("c", "sports"))
        assertEquals(posts, RankedFeedViewModel.prioritize(posts, topic = null))
    }

    @Test
    fun prioritize_movesMatchingTopicFirst_preservingRelativeOrder() {
        val posts = listOf(
            post("a", "sports"),
            post("b", "technology"),
            post("c", "sports"),
            post("d", "science"),
            post("e", "Technology"),
        )

        val ranked = RankedFeedViewModel.prioritize(posts, topic = "technology")

        assertEquals(listOf("b", "e", "a", "c", "d"), ranked.map { it.id })
    }

    @Test
    fun matchesTopic_isCaseInsensitive_andIgnoresBlank() {
        assertTrue(RankedFeedViewModel.matchesTopic(post("a", "Technology"), "technology"))
        assertFalse(RankedFeedViewModel.matchesTopic(post("b", null), "technology"))
        assertFalse(RankedFeedViewModel.matchesTopic(post("c", "  "), "technology"))
    }

    private fun post(id: String, topic: String?): Post =
        Post(
            id = id,
            userId = 1,
            username = "tester",
            content = "Post $id",
            createdAt = now,
            topic = topic,
        )
}

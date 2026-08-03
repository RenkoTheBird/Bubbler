package com.bubbler.android.data.model

import com.bubbler.android.core.network.ApiClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant

class PostTest {
    private val json = ApiClient.defaultJson()

    @Test
    fun decodesPost_withUsernameAndTopic() {
        val post = json.decodeFromString<Post>(
            """
            {
              "id": "post-1",
              "user_id": 42,
              "username": "wren",
              "content": "hello graph",
              "created_at": "2024-06-15T12:30:45.123Z",
              "topic": "technology"
            }
            """.trimIndent(),
        )

        assertEquals("post-1", post.id)
        assertEquals(42, post.userId)
        assertEquals("wren", post.username)
        assertEquals("hello graph", post.content)
        assertEquals(Instant.parse("2024-06-15T12:30:45.123Z"), post.createdAt)
        assertEquals("technology", post.topic)
        assertNull(post.embedding)
        assertEquals("@wren", post.authorLabel)
    }

    @Test
    fun authorLabel_fallsBackToUserId_whenUsernameMissing() {
        val post = json.decodeFromString<Post>(
            """
            {
              "id": "post-2",
              "user_id": 9,
              "content": "anon",
              "created_at": "2024-01-01T00:00:00Z"
            }
            """.trimIndent(),
        )

        assertNull(post.username)
        assertEquals("user #9", post.authorLabel)
    }

    @Test
    fun decodesOptionalEmbedding() {
        val post = json.decodeFromString<Post>(
            """
            {
              "id": "post-3",
              "user_id": 1,
              "content": "embedded",
              "created_at": "2025-03-20T18:00:00.000Z",
              "embedding": [0.1, 0.2, 0.3]
            }
            """.trimIndent(),
        )

        assertEquals(listOf(0.1, 0.2, 0.3), post.embedding)
    }
}

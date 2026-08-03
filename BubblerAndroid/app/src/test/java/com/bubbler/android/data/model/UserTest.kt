package com.bubbler.android.data.model

import com.bubbler.android.core.network.ApiClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class UserTest {
    private val json = ApiClient.defaultJson()

    @Test
    fun decodesOwnProfile_withEmail() {
        val user = json.decodeFromString<User>(
            """
            {
              "id": 7,
              "username": "wren",
              "email": "wren@example.com",
              "created_at": "2024-06-15T12:30:45.123Z"
            }
            """.trimIndent(),
        )

        assertEquals(7, user.id)
        assertEquals("wren", user.username)
        assertEquals("wren@example.com", user.email)
        assertEquals(Instant.parse("2024-06-15T12:30:45.123Z"), user.createdAt)
        assertFalse(user.isBlocked)
    }

    @Test
    fun decodesPublicProfile_withIsBlocked() {
        val user = json.decodeFromString<User>(
            """
            {
              "id": 3,
              "username": "neighbor",
              "created_at": "2024-01-01T00:00:00Z",
              "is_blocked": true
            }
            """.trimIndent(),
        )

        assertEquals(3, user.id)
        assertEquals("neighbor", user.username)
        assertNull(user.email)
        assertEquals(Instant.parse("2024-01-01T00:00:00Z"), user.createdAt)
        assertTrue(user.isBlocked)
    }

    @Test
    fun publicProfile_defaultsIsBlockedToFalse() {
        val user = json.decodeFromString<User>(
            """
            {
              "id": 1,
              "username": "solo",
              "created_at": "2025-03-20T18:00:00.000Z"
            }
            """.trimIndent(),
        )

        assertNull(user.email)
        assertFalse(user.isBlocked)
    }
}

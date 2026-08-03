package com.bubbler.android.data.model

import com.bubbler.android.core.network.ApiClient
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

class BlockedUserTest {
    private val json = ApiClient.defaultJson()

    @Test
    fun decodesBlockedUser() {
        val blocked = json.decodeFromString<BlockedUser>(
            """
            {
              "id": 11,
              "username": "troll",
              "blocked_at": "2024-08-01T15:45:00.500Z"
            }
            """.trimIndent(),
        )

        assertEquals(11, blocked.id)
        assertEquals("troll", blocked.username)
        assertEquals(Instant.parse("2024-08-01T15:45:00.500Z"), blocked.blockedAt)
    }
}

package com.bubbler.android.data.model

import com.bubbler.android.core.network.ApiClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchTest {
    private val json = ApiClient.defaultJson()

    @Test
    fun decodesSearchResponse() {
        val response = json.decodeFromString<SearchResponse>(
            """
            {
              "query": "space",
              "exact_matches": [
                {
                  "id": "exact-1",
                  "user_id": 2,
                  "username": "astro",
                  "content": "space news",
                  "created_at": "2024-01-01T00:00:00Z",
                  "topic": "science"
                }
              ],
              "related": [
                {
                  "id": "rel-1",
                  "user_id": 3,
                  "content": "orbit talk",
                  "created_at": "2024-02-01T00:00:00Z"
                }
              ]
            }
            """.trimIndent(),
        )

        assertEquals("space", response.query)
        assertEquals(1, response.exactMatches.size)
        assertEquals("exact-1", response.exactMatches[0].id)
        assertEquals(1, response.related.size)
        assertEquals("rel-1", response.related[0].id)
    }

    @Test
    fun emptyListsDecode() {
        val response = json.decodeFromString<SearchResponse>(
            """
            {
              "query": "zzzz",
              "exact_matches": [],
              "related": []
            }
            """.trimIndent(),
        )
        assertEquals("zzzz", response.query)
        assertTrue(response.exactMatches.isEmpty())
        assertTrue(response.related.isEmpty())
    }
}

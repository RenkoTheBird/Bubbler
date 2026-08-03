package com.bubbler.android.core.storage

import com.bubbler.android.core.network.ApiException
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LikedPostsStoreTest {
    @Test
    fun setLiked_andClear() {
        val store = LikedPostsStore(fetchLikedIds = { emptyList() })

        assertFalse(store.isLiked("p1"))
        store.setLiked("p1", liked = true)
        assertTrue(store.isLiked("p1"))
        store.setLiked("p1", liked = false)
        assertFalse(store.isLiked("p1"))

        store.setLiked("a", liked = true)
        store.setLiked("b", liked = true)
        store.clear()
        assertEquals(emptySet<String>(), store.likedPostIds.value)
    }

    @Test
    fun refresh_replacesLocalSet() = runTest {
        val store = LikedPostsStore(fetchLikedIds = { listOf("x", "y") })
        store.setLiked("stale", liked = true)

        store.refresh()

        assertEquals(setOf("x", "y"), store.likedPostIds.value)
        assertFalse(store.isLiked("stale"))
    }

    @Test
    fun refresh_keepsLocalSetOnFailure() = runTest {
        val store = LikedPostsStore(
            fetchLikedIds = { throw ApiException.Network("offline") },
        )
        store.setLiked("kept", liked = true)

        store.refresh()

        assertEquals(setOf("kept"), store.likedPostIds.value)
    }
}

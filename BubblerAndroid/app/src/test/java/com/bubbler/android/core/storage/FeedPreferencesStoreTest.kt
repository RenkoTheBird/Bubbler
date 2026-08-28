package com.bubbler.android.core.storage

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FeedPreferencesStoreTest {
    @Test
    fun missingPostIsNeutral() {
        val store = FeedPreferencesStore(fetchPreferences = { emptyMap() })
        assertEquals(com.bubbler.android.data.model.FeedPreference.NEUTRAL, store.preferenceFor("missing"))
    }

    @Test
    fun refreshLoadsPreferences() = runTest {
        val store = FeedPreferencesStore(fetchPreferences = { mapOf("x" to 2, "y" to -1) })
        store.refresh()
        assertEquals(
            com.bubbler.android.data.model.FeedPreference.MUCH_MORE,
            store.preferenceFor("x"),
        )
        assertEquals(
            com.bubbler.android.data.model.FeedPreference.MUCH_LESS,
            store.preferenceFor("y"),
        )
    }

    @Test
    fun setPreferenceUpdatesMap() {
        val store = FeedPreferencesStore(fetchPreferences = { emptyMap() })
        store.setPreference("a", com.bubbler.android.data.model.FeedPreference.MORE)
        assertTrue("a" in store.preferencesByPostId.value)
        store.setPreference("a", com.bubbler.android.data.model.FeedPreference.NEUTRAL)
        assertFalse("a" in store.preferencesByPostId.value)
    }

    @Test
    fun refreshFailureKeepsLocalState() = runTest {
        var shouldFail = true
        val store = FeedPreferencesStore(
            fetchPreferences = {
                if (shouldFail) {
                    shouldFail = false
                    error("network down")
                } else {
                    emptyMap()
                }
            },
        )
        store.setPreference("local", com.bubbler.android.data.model.FeedPreference.LESS)
        store.refresh()
        assertEquals(
            com.bubbler.android.data.model.FeedPreference.LESS,
            store.preferenceFor("local"),
        )
    }
}

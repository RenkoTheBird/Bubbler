package com.bubbler.android.data.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TopicsTest {
    @Test
    fun resolve_returnsCanonicalKnownTopic() {
        assertEquals("technology", KnownTopics.resolve("Technology"))
        assertEquals("general", KnownTopics.resolve("general"))
        assertNull(KnownTopics.resolve("not-a-topic"))
        assertNull(KnownTopics.resolve("  "))
    }

    @Test
    fun displayName_capitalizesFirstLetter() {
        assertEquals("Politics", KnownTopics.displayName("politics"))
        assertEquals("General", KnownTopics.displayName("general"))
    }

    @Test
    fun matching_filtersByQueryAndExclusions() {
        val matches = KnownTopics.matching("sci", excluding = listOf("science"))
        assertTrue(matches.none { it == "science" })
        assertTrue(matches.isEmpty() || matches.all { it.contains("sci", ignoreCase = true) })

        val allAvailable = KnownTopics.matching("", excluding = listOf("politics"))
        assertTrue(allAvailable.none { it.equals("politics", ignoreCase = true) })
        assertEquals(KnownTopics.ALL.size - 1, allAvailable.size)
    }

    @Test
    fun topicPreferenceList_cleanedDedupesAndSorts() {
        val cleaned = TopicPreferenceList.cleaned(
            listOf(" Sports ", "science", "sports", "", "Health,"),
        )
        assertEquals(listOf("Health", "science", "Sports"), cleaned)
    }

    @Test
    fun topicPreferenceList_addAndRemove() {
        val withTech = TopicPreferenceList.add("Technology", to = listOf("science"))
        assertEquals(listOf("science", "technology"), withTech)

        val unchanged = TopicPreferenceList.add("unknown", to = listOf("science"))
        assertEquals(listOf("science"), unchanged)

        val removed = TopicPreferenceList.remove("Science", from = listOf("science", "sports"))
        assertEquals(listOf("sports"), removed)
    }
}

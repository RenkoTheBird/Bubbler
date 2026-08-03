package com.bubbler.android.data.model

/**
 * Curated topic list — mirrors `backend/app/db/topics.py` KNOWN_TOPICS —
 * plus preference-list clean/add/remove helpers (Swift `TopicPreferenceList`).
 */
object KnownTopics {
    const val DEFAULT_TOPIC = "general"

    val ALL: List<String> = listOf(
        DEFAULT_TOPIC,
        "politics",
        "technology",
        "science",
        "entertainment",
        "sports",
        "business",
        "health",
        "education",
        "environment",
    )

    fun displayName(topic: String): String {
        if (topic.isEmpty()) return topic
        return topic.replaceFirstChar { it.titlecase() }
    }

    /** Returns the canonical known topic for [value], or null if not in [ALL]. */
    fun resolve(value: String): String? {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return null
        return ALL.firstOrNull { it.equals(trimmed, ignoreCase = true) }
    }

    /**
     * Topics whose names contain [query] (case-insensitive),
     * excluding already-selected ones.
     */
    fun matching(query: String, excluding: List<String> = emptyList()): List<String> {
        val trimmed = query.trim()
        val excluded = excluding.map { it.lowercase() }.toSet()
        val available = ALL.filter { it.lowercase() !in excluded }
        if (trimmed.isEmpty()) return available
        return available.filter { it.contains(trimmed, ignoreCase = true) }
    }
}

object TopicPreferenceList {
    fun cleaned(topics: List<String>): List<String> {
        val seen = mutableSetOf<String>()
        return topics
            .map { normalizedTopic(it) }
            .filter { it.isNotEmpty() }
            .filter { topic -> seen.add(topic.lowercase()) }
            .sortedWith(String.CASE_INSENSITIVE_ORDER)
    }

    fun add(rawTopic: String, to: List<String>): List<String> {
        val topic = KnownTopics.resolve(rawTopic) ?: return cleaned(to)
        val updated = cleaned(to).toMutableList()
        if (updated.any { it.equals(topic, ignoreCase = true) }) {
            return updated
        }
        updated.add(topic)
        return cleaned(updated)
    }

    fun remove(rawTopic: String, from: List<String>): List<String> {
        val topic = normalizedTopic(rawTopic)
        return cleaned(from).filter { !it.equals(topic, ignoreCase = true) }
    }

    fun normalizedTopic(value: String): String =
        value.trim().replace(",", "")
}

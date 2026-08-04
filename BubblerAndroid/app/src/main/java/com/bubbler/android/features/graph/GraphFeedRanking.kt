package com.bubbler.android.features.graph

import com.bubbler.android.data.model.GraphFeedNode
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.model.TopicPreferenceList
import com.bubbler.android.data.model.UserPreferences

/**
 * Pure ranking / preference annotation helpers shared by [GraphFeedViewModel].
 * Extracted from Swift `GraphFeedViewModel` private helpers.
 */
internal object GraphFeedRanking {
    fun rankedNodes(posts: List<Post>, preferences: UserPreferences): List<GraphFeedNode> {
        val nodes = uniqued(posts).map { makeNode(it, preferences) }
        return nodes
            .mapIndexed { index, node -> index to node }
            .sortedWith { lhs, rhs ->
                val preferredCmp = when {
                    lhs.second.isPreferredTopic != rhs.second.isPreferredTopic ->
                        if (lhs.second.isPreferredTopic) -1 else 1
                    else -> 0
                }
                if (preferredCmp != 0) preferredCmp else lhs.first.compareTo(rhs.first)
            }
            .map { it.second }
    }

    fun makeNode(post: Post, preferences: UserPreferences): GraphFeedNode {
        val normalizedTopic = normalizedTopicName(post.topic)
        return GraphFeedNode(
            post = post,
            isPreferredTopic = contains(normalizedTopic, preferences.preferredTopics),
            isBlacklistedTopic = contains(normalizedTopic, preferences.blacklistedTopics),
        )
    }

    fun normalizedTopicName(topic: String?): String? {
        if (topic == null) return null
        val normalized = TopicPreferenceList.normalizedTopic(topic)
        return normalized.ifEmpty { null }
    }

    fun contains(normalizedTopic: String?, topics: List<String>): Boolean {
        if (normalizedTopic == null) return false
        return topics.any { it.equals(normalizedTopic, ignoreCase = true) }
    }

    fun uniqued(posts: List<Post>): List<Post> {
        val seen = mutableSetOf<String>()
        return posts.filter { seen.add(it.id) }
    }

    fun statusMessage(
        node: GraphFeedNode,
        seedStrategyLabel: String?,
        defaultMessage: String,
    ): String {
        val parts = buildList {
            if (node.isPreferredTopic) {
                node.topicName?.let { add("Preferred: $it") }
            }
            seedStrategyLabel?.let { add(it) }
        }
        return if (parts.isEmpty()) defaultMessage else parts.joinToString(" · ")
    }
}

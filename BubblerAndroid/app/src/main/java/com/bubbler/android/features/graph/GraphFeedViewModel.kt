package com.bubbler.android.features.graph

import androidx.lifecycle.ViewModel
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.GraphFeedNode
import com.bubbler.android.data.model.GraphInteractionPayload
import com.bubbler.android.data.model.GraphInteractionType
import com.bubbler.android.data.model.UserPreferences
import com.bubbler.android.data.repository.FeedRepository
import com.bubbler.android.data.repository.GraphRepository
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Duration
import java.time.Instant
import kotlin.math.max

/**
 * Graph walk session state — mirrors Swift `GraphFeedViewModel`.
 *
 * Behavior to preserve (see architecture.md):
 * - Up to three session retries; force diversify after the first failure
 * - Session queue fallback when a node has no usable neighbors
 * - View-time recorded on advance
 * - Client-side preferred/blacklist flag refresh on preference changes
 */
class GraphFeedViewModel(
    private val authSession: AuthSession,
    private val feedRepository: FeedRepository,
    private val graphRepository: GraphRepository,
    private val preferencesRepository: PreferencesRepository,
    private val userRepository: UserRepository,
    private val postRepository: PostRepository,
    private val clock: () -> Instant = { Instant.now() },
) : ViewModel() {
    private val _currentNode = MutableStateFlow<GraphFeedNode?>(null)
    val currentNode: StateFlow<GraphFeedNode?> = _currentNode.asStateFlow()

    private val _nextChoices = MutableStateFlow<List<GraphFeedNode>>(emptyList())
    val nextChoices: StateFlow<List<GraphFeedNode>> = _nextChoices.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSubmitting = MutableStateFlow(false)
    val isSubmitting: StateFlow<Boolean> = _isSubmitting.asStateFlow()

    private val _seedStrategyLabel = MutableStateFlow<String?>(null)
    val seedStrategyLabel: StateFlow<String?> = _seedStrategyLabel.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _statusMessage = MutableStateFlow<String?>(null)
    val statusMessage: StateFlow<String?> = _statusMessage.asStateFlow()

    private var preferences: UserPreferences = UserPreferences.PLACEHOLDER
    private var sessionQueue: MutableList<GraphFeedNode> = mutableListOf()
    private var currentPostStartedAt: Instant? = null

    val hasCurrentPost: Boolean
        get() = _currentNode.value != null

    val currentTopicName: String
        get() = _currentNode.value?.topicName ?: "Topicless bubble"

    val hasCurrentTopic: Boolean
        get() = _currentNode.value?.topicName != null

    val isCurrentTopicPreferred: Boolean
        get() = _currentNode.value?.isPreferredTopic == true

    val isCurrentTopicBlacklisted: Boolean
        get() = _currentNode.value?.isBlacklistedTopic == true

    suspend fun load() {
        if (_isLoading.value) return
        loadSession(
            diversify = false,
            message = "Building your graph session.",
        )
    }

    suspend fun refreshSession() {
        loadSession(
            diversify = true,
            message = "Exploring a fresh path across topics.",
        )
    }

    suspend fun choose(node: GraphFeedNode) {
        advance(
            interactionType = GraphInteractionType.EXPLORE,
            explicitNextNode = node,
            fallbackMessage = "Following a connected post.",
        )
    }

    suspend fun skipCurrentPost() {
        advance(
            interactionType = GraphInteractionType.SKIP,
            explicitNextNode = null,
            fallbackMessage = "Skipping ahead to the next bubble.",
        )
    }

    fun updateCurrentPostContent(content: String) {
        val current = _currentNode.value ?: return
        val existing = current.post
        val updatedPost = existing.copy(content = content)
        _currentNode.value = GraphFeedNode(
            post = updatedPost,
            isPreferredTopic = current.isPreferredTopic,
            isBlacklistedTopic = current.isBlacklistedTopic,
        )
    }

    /** Reloads preferences after PostCard owns the prefs update. */
    suspend fun syncTopicPreferences() {
        try {
            preferences = preferencesRepository.getPreferences().sanitized()
            refreshPreferenceFlags()

            val current = _currentNode.value
            if (current != null && current.isBlacklistedTopic) {
                _nextChoices.value = emptyList()
                sessionQueue = mutableListOf()
                recordInteraction(current, GraphInteractionType.SKIP)
                loadSession(
                    diversify = true,
                    message = "Topic blacklisted. Exploring other bubbles.",
                )
            }
        } catch (error: Exception) {
            handle(error, fallbackMessage = "We couldn't refresh topic preferences.")
        }
    }

    suspend fun deleteCurrentPost() {
        val current = _currentNode.value ?: return

        _isSubmitting.value = true
        _errorMessage.value = null

        try {
            postRepository.deletePost(current.id)
            authSession.showSuccessMessage("Post deleted.")
            advanceAfterCurrentPostRemoved(successMessage = "Deleted your post and moved ahead.")
        } catch (error: Exception) {
            handle(error, fallbackMessage = "We couldn't delete that post.")
        }

        _isSubmitting.value = false
    }

    /** Called when PostCard already deleted the current post via the API. */
    suspend fun handleCurrentPostDeleted() {
        advanceAfterCurrentPostRemoved(successMessage = "Deleted your post and moved ahead.")
    }

    private suspend fun loadSession(
        diversify: Boolean = false,
        message: String,
    ) {
        _isLoading.value = true
        _errorMessage.value = null
        _statusMessage.value = message

        try {
            preferences = preferencesRepository.getPreferences().sanitized()

            val sessionNodes = fetchUsableSessionNodes(diversify = diversify)
            val firstNode = sessionNodes.firstOrNull()
                ?: throw GraphFeedError.NoUsablePosts

            sessionQueue = sessionNodes.drop(1).toMutableList()
            setCurrentNode(firstNode)

            if (_errorMessage.value == null) {
                val seedNote = _seedStrategyLabel.value?.let { " $it." }.orEmpty()
                _statusMessage.value = GraphFeedRanking.statusMessage(
                    node = firstNode,
                    seedStrategyLabel = _seedStrategyLabel.value,
                    defaultMessage = "Session ready.$seedNote",
                )
            }
        } catch (error: Exception) {
            _currentNode.value = null
            _nextChoices.value = emptyList()
            sessionQueue = mutableListOf()
            _seedStrategyLabel.value = null
            handle(error, fallbackMessage = "We couldn't build a graph session right now.")
        }

        _isLoading.value = false
    }

    private suspend fun advance(
        interactionType: GraphInteractionType,
        explicitNextNode: GraphFeedNode?,
        fallbackMessage: String,
    ) {
        val current = _currentNode.value
        if (current == null) {
            loadSession(
                diversify = false,
                message = "Building your graph session.",
            )
            return
        }

        _isSubmitting.value = true
        _errorMessage.value = null

        try {
            recordInteraction(current, interactionType)

            when {
                explicitNextNode != null -> {
                    setCurrentNode(explicitNextNode)
                    if (_errorMessage.value == null) {
                        _currentNode.value?.let { node ->
                            _statusMessage.value = GraphFeedRanking.statusMessage(
                                node = node,
                                seedStrategyLabel = _seedStrategyLabel.value,
                                defaultMessage = fallbackMessage,
                            )
                        }
                    }
                }
                else -> {
                    val nextNode = nextAutomaticNode(excludingCurrentId = current.id)
                    if (nextNode != null) {
                        setCurrentNode(nextNode)
                        if (_errorMessage.value == null) {
                            _currentNode.value?.let { node ->
                                _statusMessage.value = GraphFeedRanking.statusMessage(
                                    node = node,
                                    seedStrategyLabel = _seedStrategyLabel.value,
                                    defaultMessage = fallbackMessage,
                                )
                            }
                        }
                    } else {
                        loadSession(
                            diversify = true,
                            message = "Loading a fresh cross-topic path.",
                        )
                    }
                }
            }
        } catch (error: Exception) {
            handle(error, fallbackMessage = "We couldn't save that interaction.")
        }

        _isSubmitting.value = false
    }

    private suspend fun advanceAfterCurrentPostRemoved(successMessage: String) {
        val current = _currentNode.value ?: return

        _nextChoices.value = _nextChoices.value.filterNot { it.id == current.id }
        sessionQueue.removeAll { it.id == current.id }

        val nextNode = nextAutomaticNode(excludingCurrentId = current.id)
        if (nextNode != null) {
            setCurrentNode(nextNode)
            if (_errorMessage.value == null) {
                _statusMessage.value = successMessage
            }
        } else {
            loadSession(
                diversify = true,
                message = "Deleted your post. Exploring other bubbles.",
            )
        }
    }

    private suspend fun setCurrentNode(node: GraphFeedNode) {
        // Re-annotate from live preferences so a stale preview node can't carry old flags.
        val annotated = GraphFeedRanking.makeNode(node.post, preferences)
        if (annotated.isBlacklistedTopic) {
            loadSession(
                diversify = true,
                message = "That topic is blacklisted, so exploring other bubbles.",
            )
            return
        }

        _currentNode.value = annotated
        currentPostStartedAt = clock()

        try {
            _nextChoices.value = loadChoices(forNode = annotated)

            if (_nextChoices.value.isEmpty() && sessionQueue.isEmpty()) {
                _statusMessage.value =
                    "No connected posts were available, so the next action will pull a fresh session."
            }
        } catch (error: Exception) {
            _nextChoices.value = emptyList()
            handle(error, fallbackMessage = "We couldn't load the connected posts.")
        }
    }

    private suspend fun fetchUsableSessionNodes(
        diversify: Boolean,
        maxAttempts: Int = 3,
    ): List<GraphFeedNode> {
        var lastSeedLabel: String? = null

        repeat(maxAttempts) { attempt ->
            // Escalate to diversify on retries so blacklist / empty pools can escape.
            val forceDiversify = diversify || attempt > 0
            val session = feedRepository.getSessionFeed(diversify = forceDiversify)
            lastSeedLabel = session.statusLabel
            _seedStrategyLabel.value = session.statusLabel

            val nodes = GraphFeedRanking.rankedNodes(session.posts, preferences)
            val proposedCurrent = nodes.firstOrNull() ?: return@repeat
            if (proposedCurrent.isBlacklistedTopic) return@repeat

            val remainingNodes = nodes
                .drop(1)
                .filterNot { it.isBlacklistedTopic }

            return listOf(proposedCurrent) + remainingNodes
        }

        _seedStrategyLabel.value = lastSeedLabel
        throw GraphFeedError.NoUsablePosts
    }

    private suspend fun loadChoices(forNode: GraphFeedNode): List<GraphFeedNode> {
        val posts = graphRepository.getNextGraphPosts(forNode.id)
        return GraphFeedRanking.rankedNodes(posts, preferences)
            .filter { choice ->
                choice.id != forNode.id && !choice.isBlacklistedTopic
            }
    }

    private fun nextAutomaticNode(excludingCurrentId: String): GraphFeedNode? {
        val choice = _nextChoices.value.firstOrNull { candidate ->
            candidate.id != excludingCurrentId && !candidate.isBlacklistedTopic
        }
        if (choice != null) {
            _nextChoices.value = _nextChoices.value.filterNot {
                it.id == choice.id || it.isBlacklistedTopic
            }
            return choice
        }

        _nextChoices.value = _nextChoices.value.filterNot { it.isBlacklistedTopic }

        while (sessionQueue.isNotEmpty()) {
            val nextNode = sessionQueue.removeAt(0)
            if (nextNode.id != excludingCurrentId && !nextNode.isBlacklistedTopic) {
                return nextNode
            }
        }

        return null
    }

    private fun refreshPreferenceFlags() {
        _currentNode.value?.let { current ->
            _currentNode.value = GraphFeedRanking.makeNode(current.post, preferences)
        }

        _nextChoices.value = GraphFeedRanking.rankedNodes(
            posts = _nextChoices.value.map { it.post },
            preferences = preferences,
        )
        sessionQueue = sessionQueue
            .map { GraphFeedRanking.makeNode(it.post, preferences) }
            .toMutableList()
    }

    private suspend fun recordInteraction(node: GraphFeedNode, type: GraphInteractionType) {
        val payload = GraphInteractionPayload(
            postId = node.id,
            type = type,
            viewTime = viewTime(clock()),
        )
        userRepository.recordInteraction(payload)
    }

    private fun viewTime(at: Instant): Double {
        val started = currentPostStartedAt ?: return 0.0
        return max(0.0, Duration.between(started, at).toMillis() / 1_000.0)
    }

    private fun handle(error: Exception, fallbackMessage: String) {
        if (error is ApiException.Unauthorized) {
            authSession.signOut()
        }

        val description = error.message?.trim().orEmpty()
        _errorMessage.value = description.ifEmpty { fallbackMessage }
    }
}

private sealed class GraphFeedError(message: String) : Exception(message) {
    data object NoUsablePosts : GraphFeedError(
        "No session posts matched your current topic rules.",
    )
}

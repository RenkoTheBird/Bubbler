package com.bubbler.android.features.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.FeedRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Ranked feed state — mirrors Swift `FeedViewModel`.
 *
 * [selectedTopic] `null` means the mixed "All" feed; otherwise a KnownTopics value
 * passed as the feed `q` query. Same-topic posts are sorted first after fetch.
 */
class RankedFeedViewModel(
    private val authSession: AuthSession,
    private val feedRepository: FeedRepository,
) : ViewModel() {
    private val _selectedTopic = MutableStateFlow<String?>(null)
    val selectedTopic: StateFlow<String?> = _selectedTopic.asStateFlow()

    private val _posts = MutableStateFlow<List<Post>>(emptyList())
    val posts: StateFlow<List<Post>> = _posts.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun selectTopic(topic: String?) {
        val normalized = topic
            ?.trim()
            ?.lowercase()
            ?.takeIf { it.isNotEmpty() }

        if (_selectedTopic.value == normalized && _posts.value.isNotEmpty()) {
            return
        }

        _selectedTopic.value = normalized
        _posts.value = emptyList()
        loadFeed()
    }

    fun loadFeed() {
        viewModelScope.launch {
            if (authSession.accessToken.value == null) {
                _posts.value = emptyList()
                _errorMessage.value = null
                return@launch
            }

            _isLoading.value = true
            _errorMessage.value = null
            try {
                val fetched = feedRepository.getFeed(query = _selectedTopic.value)
                _posts.value = prioritize(posts = fetched, topic = _selectedTopic.value)
            } catch (_: ApiException.Unauthorized) {
                _posts.value = emptyList()
                _errorMessage.value = ApiException.Unauthorized.message
                authSession.signOut()
            } catch (error: Exception) {
                _posts.value = emptyList()
                _errorMessage.value = error.message ?: "Couldn't load the feed."
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun removePost(id: String) {
        _posts.value = _posts.value.filterNot { it.id == id }
    }

    fun updatePostContent(id: String, content: String) {
        _posts.value = _posts.value.map { post ->
            if (post.id == id) post.copy(content = content) else post
        }
    }

    companion object {
        /** Keeps same-topic posts first while preserving relative order within each group. */
        fun prioritize(posts: List<Post>, topic: String?): List<Post> {
            if (topic == null) return posts
            return posts
                .withIndex()
                .sortedWith(
                    compareByDescending<IndexedValue<Post>> { matchesTopic(it.value, topic) }
                        .thenBy { it.index },
                )
                .map { it.value }
        }

        fun matchesTopic(post: Post, topic: String): Boolean {
            val postTopic = post.topic?.trim().orEmpty()
            if (postTopic.isEmpty()) return false
            return postTopic.equals(topic, ignoreCase = true)
        }
    }
}

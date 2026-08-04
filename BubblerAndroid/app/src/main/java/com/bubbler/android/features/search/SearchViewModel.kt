package com.bubbler.android.features.search

import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.KnownTopics
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.SearchRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Hybrid search state — mirrors Swift `SearchViewModel`.
 *
 * Debounced live search while typing (min 2 chars); explicit submit records the
 * query in per-user recent searches. Exact matches for known-topic queries are
 * reordered so same-topic posts lead.
 */
class SearchViewModel(
    private val authSession: AuthSession,
    private val searchRepository: SearchRepository,
    private val prefs: SharedPreferences,
) : ViewModel() {
    private val _searchText = MutableStateFlow("")
    val searchText: StateFlow<String> = _searchText.asStateFlow()

    private val _exactMatches = MutableStateFlow<List<Post>>(emptyList())
    val exactMatches: StateFlow<List<Post>> = _exactMatches.asStateFlow()

    private val _related = MutableStateFlow<List<Post>>(emptyList())
    val related: StateFlow<List<Post>> = _related.asStateFlow()

    private val _recentSearches = MutableStateFlow<List<String>>(emptyList())
    val recentSearches: StateFlow<List<String>> = _recentSearches.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _hasSearched = MutableStateFlow(false)
    val hasSearched: StateFlow<Boolean> = _hasSearched.asStateFlow()

    private val _lastQuery = MutableStateFlow("")
    val lastQuery: StateFlow<String> = _lastQuery.asStateFlow()

    val posts: List<Post>
        get() = _exactMatches.value + _related.value

    private var loadedUserId: Int? = null
    private var searchEpoch: Int = 0
    private var debounceJob: Job? = null

    fun updateSearchText(value: String) {
        _searchText.value = value
        scheduleLiveSearch()
    }

    fun loadRecentSearches(userId: Int?) {
        if (userId == null) {
            _recentSearches.value = emptyList()
            loadedUserId = null
            return
        }
        if (loadedUserId == userId) return
        loadedUserId = userId
        _recentSearches.value = loadStoredSearches(prefs, userId)
    }

    /** Debounced live search while typing (skips empty / very short drafts). */
    fun scheduleLiveSearch() {
        debounceJob?.cancel()
        val trimmed = _searchText.value.trim()
        if (trimmed.length < 2) {
            if (trimmed.isEmpty()) {
                clearResults()
            }
            return
        }

        debounceJob = viewModelScope.launch {
            delay(LIVE_SEARCH_DEBOUNCE_MS)
            search(query = trimmed, recordRecent = false)
        }
    }

    suspend fun search(query: String? = null, recordRecent: Boolean = true) {
        val trimmed = (query ?: _searchText.value).trim()
        if (trimmed.isEmpty()) {
            _errorMessage.value = "Enter a search to find bubbles."
            return
        }

        if (authSession.accessToken.value == null) {
            _exactMatches.value = emptyList()
            _related.value = emptyList()
            _errorMessage.value = null
            return
        }

        val epoch = ++searchEpoch
        debounceJob?.cancel()
        _searchText.value = trimmed
        _isLoading.value = true
        _errorMessage.value = null
        _hasSearched.value = true
        _lastQuery.value = trimmed

        try {
            val response = searchRepository.search(trimmed)
            if (epoch != searchEpoch) return
            _exactMatches.value = prioritizeTopicMatches(
                posts = response.exactMatches,
                query = trimmed,
            )
            _related.value = response.related
            if (recordRecent) {
                val userId = authSession.userId.value
                if (userId != null) {
                    _recentSearches.value = record(prefs, trimmed, userId)
                    loadedUserId = userId
                }
            }
        } catch (e: CancellationException) {
            throw e
        } catch (_: ApiException.Unauthorized) {
            if (epoch != searchEpoch) return
            _exactMatches.value = emptyList()
            _related.value = emptyList()
            _errorMessage.value = ApiException.Unauthorized.message
            authSession.signOut()
        } catch (error: Exception) {
            if (epoch != searchEpoch) return
            _exactMatches.value = emptyList()
            _related.value = emptyList()
            _errorMessage.value = error.message ?: "Couldn't search."
        } finally {
            if (epoch == searchEpoch) {
                _isLoading.value = false
            }
        }
    }

    fun runRecentSearch(query: String) {
        debounceJob?.cancel()
        viewModelScope.launch {
            search(query = query, recordRecent = true)
        }
    }

    fun clearResults() {
        searchEpoch += 1
        debounceJob?.cancel()
        _exactMatches.value = emptyList()
        _related.value = emptyList()
        _hasSearched.value = false
        _lastQuery.value = ""
        _errorMessage.value = null
        _isLoading.value = false
    }

    fun clearSearch() {
        _searchText.value = ""
        clearResults()
    }

    fun removePost(id: String) {
        _exactMatches.value = _exactMatches.value.filterNot { it.id == id }
        _related.value = _related.value.filterNot { it.id == id }
    }

    fun updatePostContent(id: String, content: String) {
        _exactMatches.value = _exactMatches.value.map { post ->
            if (post.id == id) post.copy(content = content) else post
        }
        _related.value = _related.value.map { post ->
            if (post.id == id) post.copy(content = content) else post
        }
    }

    companion object {
        private const val MAX_RECENT_SEARCHES = 5
        private const val LIVE_SEARCH_DEBOUNCE_MS = 350L
        private val json = Json { ignoreUnknownKeys = true }

        /** When the query equals a known topic, keep same-topic posts first. */
        fun prioritizeTopicMatches(posts: List<Post>, query: String): List<Post> {
            val normalized = query.trim().lowercase()
            if (KnownTopics.resolve(normalized) == null) return posts

            return posts
                .withIndex()
                .sortedWith(
                    compareByDescending<IndexedValue<Post>> { matchesTopic(it.value, normalized) }
                        .thenBy { it.index },
                )
                .map { it.value }
        }

        fun matchesTopic(post: Post, topic: String): Boolean {
            val postTopic = post.topic?.trim().orEmpty()
            if (postTopic.isEmpty()) return false
            return postTopic.equals(topic, ignoreCase = true)
        }

        fun storageKey(userId: Int): String = "recentSearches.$userId"

        fun loadStoredSearches(prefs: SharedPreferences, userId: Int): List<String> {
            val raw = prefs.getString(storageKey(userId), null) ?: return emptyList()
            return try {
                json.decodeFromString<List<String>>(raw)
            } catch (_: Exception) {
                emptyList()
            }
        }

        fun record(prefs: SharedPreferences, query: String, userId: Int): List<String> {
            val updated = loadStoredSearches(prefs, userId)
                .filterNot { it.equals(query, ignoreCase = true) }
                .toMutableList()
            updated.add(0, query)
            val capped = updated.take(MAX_RECENT_SEARCHES)
            prefs.edit()
                .putString(storageKey(userId), json.encodeToString(capped))
                .apply()
            return capped
        }
    }
}

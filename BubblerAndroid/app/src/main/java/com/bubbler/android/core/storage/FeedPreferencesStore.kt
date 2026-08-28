package com.bubbler.android.core.storage

import com.bubbler.android.data.model.FeedPreference
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Shared feed-preference state so sliders stay consistent across Graph, Feed, and Search.
 * Mirrors iOS `FeedPreferencesStore`.
 */
class FeedPreferencesStore(
    private val fetchPreferences: suspend () -> Map<String, Int>,
) {
    constructor(userRepository: UserRepository) : this {
        userRepository.getFeedPreferences().associate { it.postId to it.feedPreference }
    }

    private val _preferencesByPostId = MutableStateFlow<Map<String, Int>>(emptyMap())
    val preferencesByPostId: StateFlow<Map<String, Int>> = _preferencesByPostId.asStateFlow()

    fun preferenceFor(postId: String): FeedPreference =
        FeedPreference.fromRaw(_preferencesByPostId.value[postId] ?: 0)

    fun setPreference(postId: String, preference: FeedPreference) {
        _preferencesByPostId.update { current ->
            if (preference == FeedPreference.NEUTRAL) {
                current - postId
            } else {
                current + (postId to preference.rawValue)
            }
        }
    }

    suspend fun refresh() {
        try {
            _preferencesByPostId.value = fetchPreferences()
        } catch (_: Exception) {
            // Keep the local map if preferences can't be loaded.
        }
    }

    fun clear() {
        _preferencesByPostId.value = emptyMap()
    }
}

/** Backward-compatible alias while call sites migrate. */
typealias LikedPostsStore = FeedPreferencesStore

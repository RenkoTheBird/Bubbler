package com.bubbler.android.core.storage

import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Shared liked-post IDs so hearts stay consistent across Graph, Feed, and Search.
 * Mirrors iOS `LikedPostsStore`.
 */
class LikedPostsStore(
    private val fetchLikedIds: suspend () -> List<String>,
) {
    constructor(userRepository: UserRepository) : this(userRepository::getLikedPostIds)

    private val _likedPostIds = MutableStateFlow<Set<String>>(emptySet())
    val likedPostIds: StateFlow<Set<String>> = _likedPostIds.asStateFlow()

    fun isLiked(postId: String): Boolean = postId in _likedPostIds.value

    fun setLiked(postId: String, liked: Boolean) {
        _likedPostIds.update { current ->
            if (liked) current + postId else current - postId
        }
    }

    suspend fun refresh() {
        try {
            _likedPostIds.value = fetchLikedIds().toSet()
        } catch (_: Exception) {
            // Keep the local set if likes can't be loaded.
        }
    }

    fun clear() {
        _likedPostIds.value = emptySet()
    }
}

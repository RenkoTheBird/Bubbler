package com.bubbler.android.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.KnownTopics
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.BlocksRepository
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Own or public profile — mirrors Swift `ProfileViewModel`.
 *
 * [targetUsername] `null` loads `/user/me/...`; otherwise a public profile.
 * Soft refresh keeps existing posts visible so tab switches don't flash empty.
 */
class ProfileViewModel(
    private val authSession: AuthSession,
    private val userRepository: UserRepository,
    private val blocksRepository: BlocksRepository,
    targetUsername: String? = null,
) : ViewModel() {
    val targetUsername: String? =
        targetUsername?.trim()?.takeIf { it.isNotEmpty() }

    private val _userId = MutableStateFlow<Int?>(null)
    val userId: StateFlow<Int?> = _userId.asStateFlow()

    private val _username = MutableStateFlow<String?>(null)
    val username: StateFlow<String?> = _username.asStateFlow()

    private val _posts = MutableStateFlow<List<Post>>(emptyList())
    val posts: StateFlow<List<Post>> = _posts.asStateFlow()

    private val _isBlocked = MutableStateFlow(false)
    val isBlocked: StateFlow<Boolean> = _isBlocked.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isUpdatingBlock = MutableStateFlow(false)
    val isUpdatingBlock: StateFlow<Boolean> = _isUpdatingBlock.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var hasLoaded = false

    val isOwnProfile: Boolean
        get() = targetUsername == null

    fun isOwnProfile(sessionUserId: Int?): Boolean {
        if (isOwnProfile) return true
        val loadedId = _userId.value ?: return false
        return sessionUserId != null && loadedId == sessionUserId
    }

    fun canManageBlock(sessionUserId: Int?): Boolean =
        !isOwnProfile(sessionUserId) &&
            _username.value != null &&
            !_isLoading.value

    fun displayUsername(username: String?, isLoading: Boolean): String {
        val name = username?.trim().orEmpty()
        if (name.isNotEmpty()) return "@$name"
        return if (isLoading) "Loading..." else "@…"
    }

    fun profileSubtitle(isBlocked: Boolean): String = when {
        isBlocked -> "You blocked this user"
        isOwnProfile -> "Your bubble profile"
        else -> "Bubble node in your network"
    }

    fun activeBubbleLabel(posts: List<Post>, isLoading: Boolean): String {
        val topic = uniqueTopics(from = posts).firstOrNull()
        return when {
            topic != null -> "Active Bubble: ${KnownTopics.displayName(topic)}"
            isLoading -> "Loading bubbles…"
            else -> "No active bubble yet"
        }
    }

    fun emptyPostsMessage(isLoading: Boolean): String = when {
        isLoading && isOwnProfile -> "Loading your posts…"
        isLoading -> "Loading posts…"
        isOwnProfile -> "Posts you create will show up here."
        else -> "No posts yet."
    }

    fun loadProfile(force: Boolean = false) {
        if (!force && hasLoaded) return
        viewModelScope.launch {
            loadProfileInternal(force = force)
        }
    }

    suspend fun refreshPosts() {
        loadProfileInternal(force = true)
    }

    fun blockUser() {
        viewModelScope.launch { blockUserInternal() }
    }

    fun unblockUser() {
        viewModelScope.launch { unblockUserInternal() }
    }

    suspend fun blockUserAwait() = blockUserInternal()

    suspend fun unblockUserAwait() = unblockUserInternal()

    fun removePost(id: String) {
        _posts.value = _posts.value.filterNot { it.id == id }
    }

    fun updatePostContent(id: String, content: String) {
        _posts.value = _posts.value.map { post ->
            if (post.id == id) post.copy(content = content) else post
        }
    }

    private suspend fun loadProfileInternal(force: Boolean) {
        if (!force && hasLoaded) return

        val showLoadingPlaceholder = _posts.value.isEmpty()
        if (showLoadingPlaceholder) {
            _isLoading.value = true
        }
        _errorMessage.value = null

        try {
            val target = targetUsername
            if (target != null) {
                coroutineScope {
                    val profileDeferred = async { userRepository.getUser(target) }
                    val postsDeferred = async { userRepository.getUserPosts(target) }
                    val profile = profileDeferred.await()
                    val loadedPosts = postsDeferred.await()
                    _userId.value = profile.id
                    _username.value = profile.username
                    _isBlocked.value = profile.isBlocked
                    _posts.value = loadedPosts
                }
            } else {
                coroutineScope {
                    val profileDeferred = async { userRepository.getProfile() }
                    val postsDeferred = async { userRepository.getMyPosts() }
                    val profile = profileDeferred.await()
                    val loadedPosts = postsDeferred.await()
                    _userId.value = profile.id
                    _username.value = profile.username
                    _isBlocked.value = false
                    _posts.value = loadedPosts
                }
            }
            hasLoaded = true
        } catch (_: ApiException.Unauthorized) {
            authSession.signOut()
            _errorMessage.value = fallbackLoadError()
        } catch (error: Exception) {
            val description = error.message?.trim().orEmpty()
            _errorMessage.value = description.ifEmpty { fallbackLoadError() }
        } finally {
            _isLoading.value = false
        }
    }

    private suspend fun blockUserInternal() {
        val name = _username.value ?: return
        if (!canManageBlock(authSession.userId.value) || _isUpdatingBlock.value) return

        _isUpdatingBlock.value = true
        _errorMessage.value = null
        try {
            val profile = blocksRepository.blockUser(name)
            _userId.value = profile.id
            _username.value = profile.username
            _isBlocked.value = profile.isBlocked
        } catch (_: ApiException.Unauthorized) {
            authSession.signOut()
            _errorMessage.value = "We couldn't block this user."
        } catch (error: Exception) {
            val description = error.message?.trim().orEmpty()
            _errorMessage.value = description.ifEmpty { "We couldn't block this user." }
        } finally {
            _isUpdatingBlock.value = false
        }
    }

    private suspend fun unblockUserInternal() {
        val name = _username.value ?: return
        if (!canManageBlock(authSession.userId.value) || _isUpdatingBlock.value) return

        _isUpdatingBlock.value = true
        _errorMessage.value = null
        try {
            val profile = blocksRepository.unblockUser(name)
            _userId.value = profile.id
            _username.value = profile.username
            _isBlocked.value = profile.isBlocked
        } catch (_: ApiException.Unauthorized) {
            authSession.signOut()
            _errorMessage.value = "We couldn't unblock this user."
        } catch (error: Exception) {
            val description = error.message?.trim().orEmpty()
            _errorMessage.value = description.ifEmpty { "We couldn't unblock this user." }
        } finally {
            _isUpdatingBlock.value = false
        }
    }

    private fun fallbackLoadError(): String =
        if (isOwnProfile) {
            "We couldn't load your profile."
        } else {
            "We couldn't load this profile."
        }

    companion object {
        /** Topics from posts, most recently posted first, case-insensitive unique. */
        fun uniqueTopics(from: List<Post>): List<String> {
            val seen = linkedSetOf<String>()
            val topics = mutableListOf<String>()
            for (post in from) {
                val raw = post.topic?.trim().orEmpty()
                if (raw.isEmpty()) continue
                val key = raw.lowercase()
                if (!seen.add(key)) continue
                topics.add(raw)
            }
            return topics
        }
    }
}

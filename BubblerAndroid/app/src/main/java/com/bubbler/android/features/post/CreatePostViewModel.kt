package com.bubbler.android.features.post

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.KnownTopics
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.PostRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Create / edit post form — mirrors Swift `CreatePostViewModel`.
 *
 * Create posts with content + topic. Edits update content, then sync topic via
 * add/remove topic mutations when the selection changed.
 */
class CreatePostViewModel(
    private val authSession: AuthSession,
    private val postRepository: PostRepository,
    post: Post? = null,
) : ViewModel() {
    private val editingPostId: String? = post?.id
    private val originalTopic: String?

    private val _content = MutableStateFlow(post?.content.orEmpty())
    val content: StateFlow<String> = _content.asStateFlow()

    private val _selectedTopic = MutableStateFlow(KnownTopics.DEFAULT_TOPIC)
    val selectedTopic: StateFlow<String> = _selectedTopic.asStateFlow()

    private val _isSubmitting = MutableStateFlow(false)
    val isSubmitting: StateFlow<Boolean> = _isSubmitting.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    val isEditing: Boolean
        get() = editingPostId != null

    val canSubmit: Boolean
        get() = !_isSubmitting.value && _content.value.trim().isNotEmpty()

    init {
        if (post != null) {
            val topic = post.topic?.trim().orEmpty()
            val match = KnownTopics.ALL.firstOrNull { it.equals(topic, ignoreCase = true) }
            if (match != null) {
                _selectedTopic.value = match
                originalTopic = match
            } else {
                originalTopic = post.topic
            }
        } else {
            originalTopic = null
        }
    }

    fun updateContent(value: String) {
        _content.value = value
    }

    fun selectTopic(topic: String) {
        _selectedTopic.value = KnownTopics.resolve(topic) ?: KnownTopics.DEFAULT_TOPIC
    }

    /**
     * Submits create or update. Returns trimmed content on success (for callers to
     * refresh lists / update local state); null on validation or API failure.
     */
    fun submit(onResult: (String?) -> Unit) {
        viewModelScope.launch {
            onResult(submitInternal())
        }
    }

    private suspend fun submitInternal(): String? {
        val trimmedContent = _content.value.trim()
        if (trimmedContent.isEmpty()) {
            _errorMessage.value = "Write something before posting."
            return null
        }

        _isSubmitting.value = true
        _errorMessage.value = null
        return try {
            val editingId = editingPostId
            if (editingId != null) {
                postRepository.updatePost(id = editingId, content = trimmedContent)
                syncEditedTopic(postId = editingId)
                authSession.showSuccessMessage("Post updated!")
            } else {
                postRepository.createPost(
                    content = trimmedContent,
                    topic = _selectedTopic.value,
                )
                authSession.showSuccessMessage("Post published!")
            }
            trimmedContent
        } catch (_: ApiException.Unauthorized) {
            _errorMessage.value = ApiException.Unauthorized.message
            authSession.signOut()
            null
        } catch (error: Exception) {
            _errorMessage.value = error.message ?: "Couldn't save the post."
            null
        } finally {
            _isSubmitting.value = false
        }
    }

    /** Adds the newly chosen topic, then removes the previous one when it changed. */
    private suspend fun syncEditedTopic(postId: String) {
        val selected = _selectedTopic.value
        val topicChanged = originalTopic?.let {
            !it.equals(selected, ignoreCase = true)
        } ?: true

        if (!topicChanged) return

        postRepository.addPostTopic(postId = postId, topic = selected)

        val previous = originalTopic
        if (previous != null && !previous.equals(selected, ignoreCase = true)) {
            postRepository.removePostTopic(postId = postId, topic = previous)
        }
    }

    companion object {
        /** Exposed for unit tests — mirrors [syncEditedTopic] change detection. */
        fun topicNeedsSync(originalTopic: String?, selectedTopic: String): Boolean =
            originalTopic?.let { !it.equals(selectedTopic, ignoreCase = true) } ?: true
    }
}

package com.bubbler.android.features.post

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.PostRepository

class CreatePostViewModelFactory(
    private val authSession: AuthSession,
    private val postRepository: PostRepository,
    private val post: Post? = null,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(CreatePostViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return CreatePostViewModel(
            authSession = authSession,
            postRepository = postRepository,
            post = post,
        ) as T
    }
}

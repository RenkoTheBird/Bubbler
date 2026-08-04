package com.bubbler.android.features.graph

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.FeedRepository
import com.bubbler.android.data.repository.GraphRepository
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository

class GraphFeedViewModelFactory(
    private val authSession: AuthSession,
    private val feedRepository: FeedRepository,
    private val graphRepository: GraphRepository,
    private val preferencesRepository: PreferencesRepository,
    private val userRepository: UserRepository,
    private val postRepository: PostRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(GraphFeedViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return GraphFeedViewModel(
            authSession = authSession,
            feedRepository = feedRepository,
            graphRepository = graphRepository,
            preferencesRepository = preferencesRepository,
            userRepository = userRepository,
            postRepository = postRepository,
        ) as T
    }
}

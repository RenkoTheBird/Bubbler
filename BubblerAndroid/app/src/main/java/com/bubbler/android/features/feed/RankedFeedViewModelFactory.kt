package com.bubbler.android.features.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.FeedRepository

class RankedFeedViewModelFactory(
    private val authSession: AuthSession,
    private val feedRepository: FeedRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(RankedFeedViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return RankedFeedViewModel(
            authSession = authSession,
            feedRepository = feedRepository,
        ) as T
    }
}

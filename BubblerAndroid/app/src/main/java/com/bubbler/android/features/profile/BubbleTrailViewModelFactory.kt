package com.bubbler.android.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.UserRepository

class BubbleTrailViewModelFactory(
    private val authSession: AuthSession,
    private val userRepository: UserRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(BubbleTrailViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return BubbleTrailViewModel(
            authSession = authSession,
            userRepository = userRepository,
        ) as T
    }
}

package com.bubbler.android.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.BlocksRepository
import com.bubbler.android.data.repository.UserRepository

class ProfileViewModelFactory(
    private val authSession: AuthSession,
    private val userRepository: UserRepository,
    private val blocksRepository: BlocksRepository,
    private val targetUsername: String? = null,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(ProfileViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return ProfileViewModel(
            authSession = authSession,
            userRepository = userRepository,
            blocksRepository = blocksRepository,
            targetUsername = targetUsername,
        ) as T
    }
}

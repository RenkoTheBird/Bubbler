package com.bubbler.android.features.settings.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.UserRepository

class AccountViewModelFactory(
    private val authSession: AuthSession,
    private val userRepository: UserRepository,
    private val authRepository: AuthRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(AccountViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return AccountViewModel(
            authSession = authSession,
            userRepository = userRepository,
            authRepository = authRepository,
        ) as T
    }
}

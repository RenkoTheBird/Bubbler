package com.bubbler.android.features.settings.preferences

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.PreferencesRepository

class PreferencesViewModelFactory(
    private val authSession: AuthSession,
    private val preferencesRepository: PreferencesRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(PreferencesViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return PreferencesViewModel(
            authSession = authSession,
            preferencesRepository = preferencesRepository,
        ) as T
    }
}

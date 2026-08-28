package com.bubbler.android.features.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.FeedPreset
import com.bubbler.android.data.model.UserPreferences
import com.bubbler.android.data.repository.PreferencesRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class OnboardingViewModel(
    private val preferencesRepository: PreferencesRepository,
) : ViewModel() {
    private val _preferences = MutableStateFlow(UserPreferences.systemDefaults(userId = 0))
    val preferences: StateFlow<UserPreferences> = _preferences.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun loadPreferences(authSession: AuthSession) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                _preferences.value = preferencesRepository.getPreferences().sanitized()
            } catch (e: Exception) {
                handleSessionError(e, authSession, "We couldn't load your feed settings.")
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun selectPreset(preset: FeedPreset) {
        _preferences.value = _preferences.value.applyPreset(preset)
    }

    fun completeOnboarding(authSession: AuthSession, onSuccess: () -> Unit) {
        viewModelScope.launch {
            _isSaving.value = true
            _errorMessage.value = null
            try {
                val payload = _preferences.value
                    .sanitized()
                    .copy(onboardingCompleted = true)
                    .updatePayload
                val saved = preferencesRepository.updatePreferences(payload)
                _preferences.value = saved.sanitized()
                authSession.markOnboardingComplete()
                onSuccess()
            } catch (e: Exception) {
                handleSessionError(e, authSession, "We couldn't save your feed settings.")
            } finally {
                _isSaving.value = false
            }
        }
    }

    fun useRecommendedDefaults(authSession: AuthSession, onSuccess: () -> Unit) {
        val userId = authSession.userId.value ?: _preferences.value.userId
        _preferences.value = UserPreferences.systemDefaults(userId = userId)
        completeOnboarding(authSession, onSuccess)
    }

    private fun handleSessionError(error: Exception, authSession: AuthSession, fallback: String) {
        if (error is ApiException.Unauthorized) {
            authSession.signOut()
        }
        val description = error.message?.trim().orEmpty()
        _errorMessage.value = description.ifEmpty { fallback }
    }
}

package com.bubbler.android.features.settings.preferences

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.FeedStrategyWeights
import com.bubbler.android.data.model.UserPreferences
import com.bubbler.android.data.repository.PreferencesRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Recommendation preferences — mirrors Swift `PreferencesSettingsViewModel`.
 *
 * Strategy weights are normalized via [UserPreferences.sanitized] before PUT.
 */
class PreferencesViewModel(
    private val authSession: AuthSession,
    private val preferencesRepository: PreferencesRepository,
) : ViewModel() {
    private val _preferences = MutableStateFlow(UserPreferences.PLACEHOLDER)
    val preferences: StateFlow<UserPreferences> = _preferences.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _errorTitle = MutableStateFlow("Couldn't load preferences")
    val errorTitle: StateFlow<String> = _errorTitle.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _successMessage = MutableStateFlow<String?>(null)
    val successMessage: StateFlow<String?> = _successMessage.asStateFlow()

    private var hasLoaded = false

    fun updatePreferences(transform: (UserPreferences) -> UserPreferences) {
        _preferences.value = transform(_preferences.value)
    }

    fun updateDiversity(value: Double) {
        updatePreferences { it.copy(diversityTolerance = value) }
    }

    fun updateRandomness(value: Double) {
        updatePreferences { it.copy(randomness = value) }
    }

    fun updateUseRecency(value: Boolean) {
        updatePreferences { it.copy(useRecency = value) }
    }

    fun updateStrategyWeights(transform: (FeedStrategyWeights) -> FeedStrategyWeights) {
        updatePreferences { prefs ->
            prefs.copy(strategyWeights = transform(prefs.strategyWeights))
        }
    }

    fun updatePreferredTopics(topics: List<String>) {
        updatePreferences { it.updatePreferredTopics(topics) }
    }

    fun updateBlacklistedTopics(topics: List<String>) {
        updatePreferences { it.updateBlacklistedTopics(topics) }
    }

    fun updateUseViewTime(value: Boolean) {
        updatePreferences { it.copy(useViewTime = value) }
    }

    fun updateViewTimeWeight(value: Double) {
        updatePreferences { it.copy(viewTimeWeight = value) }
    }

    fun updateAiTopicDetection(value: Boolean) {
        if (!IS_AI_TOPIC_DETECTION_AVAILABLE) return
        updatePreferences { it.copy(aiTopicDetection = value) }
    }

    fun loadPreferences(force: Boolean = false) {
        if (!force && hasLoaded) return
        viewModelScope.launch { loadPreferencesInternal(force = force) }
    }

    /** Force-refresh so graph/feed topic edits aren't stale — mirrors iOS `.task`. */
    fun refreshFromServer() {
        viewModelScope.launch { loadPreferencesInternal(force = true) }
    }

    suspend fun refreshFromServerAwait() {
        loadPreferencesInternal(force = true)
    }

    fun reloadPreferences() {
        hasLoaded = false
        loadPreferences(force = true)
    }

    suspend fun reloadPreferencesAwait() {
        hasLoaded = false
        loadPreferencesInternal(force = true)
    }

    fun restoreDefaults() {
        val userId = _preferences.value.userId
        _preferences.value = applyFeatureGates(UserPreferences.systemDefaults(userId))
        _errorMessage.value = null
        _successMessage.value =
            "Defaults restored locally. Tap Save Preferences to apply them."
    }

    fun savePreferences() {
        viewModelScope.launch { savePreferencesInternal() }
    }

    suspend fun savePreferencesAwait() = savePreferencesInternal()

    private suspend fun loadPreferencesInternal(force: Boolean) {
        if (!force && hasLoaded) return

        // Only flash the loading card on the first fetch (matches iOS).
        if (!hasLoaded) {
            _isLoading.value = true
        }
        _errorTitle.value = "Couldn't load preferences"
        _errorMessage.value = null

        try {
            _preferences.value = applyFeatureGates(preferencesRepository.getPreferences())
            hasLoaded = true
        } catch (e: Exception) {
            handleSessionError(e, fallbackMessage = "We couldn't fetch your saved preferences.")
        }

        _isLoading.value = false
    }

    private suspend fun savePreferencesInternal() {
        _isSaving.value = true
        _errorTitle.value = "Couldn't save preferences"
        _errorMessage.value = null
        _successMessage.value = null

        try {
            val gated = applyFeatureGates(_preferences.value)
            val sanitized = gated.sanitized()
            val saved = preferencesRepository.updatePreferences(sanitized.updatePayload)
            _preferences.value = applyFeatureGates(saved)
            _successMessage.value = "Your recommendation settings were saved successfully."
        } catch (e: Exception) {
            handleSessionError(e, fallbackMessage = "We couldn't save your preferences.")
        }

        _isSaving.value = false
    }

    private fun applyFeatureGates(preferences: UserPreferences): UserPreferences {
        if (IS_AI_TOPIC_DETECTION_AVAILABLE) return preferences
        return if (preferences.aiTopicDetection) {
            preferences.copy(aiTopicDetection = false)
        } else {
            preferences
        }
    }

    private fun handleSessionError(error: Exception, fallbackMessage: String) {
        if (error is ApiException.Unauthorized) {
            authSession.signOut()
        }
        val description = error.message?.trim().orEmpty()
        _errorMessage.value = description.ifEmpty { fallbackMessage }
    }

    companion object {
        /** Flip when AI topic detection / contribution is hooked up server-side. */
        const val IS_AI_TOPIC_DETECTION_AVAILABLE = false
    }
}

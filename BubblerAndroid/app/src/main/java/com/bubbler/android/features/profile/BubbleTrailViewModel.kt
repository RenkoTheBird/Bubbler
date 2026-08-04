package com.bubbler.android.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.Interaction
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Own-user interaction history — mirrors Swift `BubbleTrailViewModel`.
 *
 * Loads `GET /user/me` interactions (server-capped). Own profile only.
 */
class BubbleTrailViewModel(
    private val authSession: AuthSession,
    private val userRepository: UserRepository,
) : ViewModel() {
    private val _interactions = MutableStateFlow<List<Interaction>>(emptyList())
    val interactions: StateFlow<List<Interaction>> = _interactions.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var hasLoaded = false

    fun load(force: Boolean = false) {
        if (!force && hasLoaded) return
        viewModelScope.launch {
            loadInternal(force = force)
        }
    }

    suspend fun loadAwait(force: Boolean = false) {
        loadInternal(force = force)
    }

    private suspend fun loadInternal(force: Boolean) {
        if (!force && hasLoaded) return

        _isLoading.value = true
        _errorMessage.value = null
        try {
            _interactions.value = userRepository.getMyInteractions()
            hasLoaded = true
        } catch (_: ApiException.Unauthorized) {
            authSession.signOut()
            _errorMessage.value = "We couldn't load your bubble trail."
        } catch (error: Exception) {
            val description = error.message?.trim().orEmpty()
            _errorMessage.value = description.ifEmpty {
                "We couldn't load your bubble trail."
            }
        } finally {
            _isLoading.value = false
        }
    }
}

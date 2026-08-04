package com.bubbler.android.features.settings.blocks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.BlockedUser
import com.bubbler.android.data.repository.BlocksRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Blocked-users list — mirrors Swift `BlockedViewModel`.
 */
class BlocksViewModel(
    private val authSession: AuthSession,
    private val blocksRepository: BlocksRepository,
) : ViewModel() {
    private val _blockedUsers = MutableStateFlow<List<BlockedUser>>(emptyList())
    val blockedUsers: StateFlow<List<BlockedUser>> = _blockedUsers.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isUpdating = MutableStateFlow(false)
    val isUpdating: StateFlow<Boolean> = _isUpdating.asStateFlow()

    private val _errorTitle = MutableStateFlow("Couldn't load blocked users")
    val errorTitle: StateFlow<String> = _errorTitle.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var hasLoaded = false

    fun loadBlockedUsers(force: Boolean = false) {
        if (!force && hasLoaded) return
        viewModelScope.launch { loadBlockedUsersInternal(force = force) }
    }

    suspend fun loadBlockedUsersAwait(force: Boolean = false) {
        loadBlockedUsersInternal(force = force)
    }

    fun unblock(user: BlockedUser) {
        viewModelScope.launch { unblockInternal(user) }
    }

    suspend fun unblockAwait(user: BlockedUser) = unblockInternal(user)

    private suspend fun loadBlockedUsersInternal(force: Boolean) {
        if (!force && hasLoaded) return

        _isLoading.value = true
        _errorTitle.value = "Couldn't load blocked users"
        _errorMessage.value = null

        try {
            _blockedUsers.value = blocksRepository.getBlockedUsers()
            hasLoaded = true
        } catch (e: Exception) {
            handleSessionError(e, fallbackMessage = "We couldn't load your blocked users.")
        }

        _isLoading.value = false
    }

    private suspend fun unblockInternal(user: BlockedUser) {
        if (_isUpdating.value) return

        _isUpdating.value = true
        _errorTitle.value = "Couldn't unblock user"
        _errorMessage.value = null

        try {
            blocksRepository.unblockUser(username = user.username)
            _blockedUsers.value = _blockedUsers.value.filterNot { it.id == user.id }
        } catch (e: Exception) {
            handleSessionError(
                e,
                fallbackMessage = "We couldn't unblock @${user.username}.",
            )
        }

        _isUpdating.value = false
    }

    private fun handleSessionError(error: Exception, fallbackMessage: String) {
        if (error is ApiException.Unauthorized) {
            authSession.signOut()
            return
        }
        val description = error.message?.trim().orEmpty()
        _errorMessage.value = description.ifEmpty { fallbackMessage }
    }
}

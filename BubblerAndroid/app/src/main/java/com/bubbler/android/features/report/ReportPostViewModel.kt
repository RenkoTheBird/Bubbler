package com.bubbler.android.features.report

import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.ReportReason
import com.bubbler.android.data.repository.BlocksRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Report-post form state — mirrors Swift `ReportPostViewModel`.
 *
 * Report submit is UI-only until the review-queue API lands.
 * When [alsoBlockUser] is on, the existing block endpoint is called immediately.
 */
class ReportPostViewModel {
    private val _selectedReason = MutableStateFlow<ReportReason?>(null)
    val selectedReason: StateFlow<ReportReason?> = _selectedReason.asStateFlow()

    private val _comments = MutableStateFlow("")
    val comments: StateFlow<String> = _comments.asStateFlow()

    private val _alsoBlockUser = MutableStateFlow(false)
    val alsoBlockUser: StateFlow<Boolean> = _alsoBlockUser.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isSubmitting = MutableStateFlow(false)
    val isSubmitting: StateFlow<Boolean> = _isSubmitting.asStateFlow()

    val canSubmit: Boolean
        get() = _selectedReason.value != null && !_isSubmitting.value

    fun selectReason(reason: ReportReason) {
        _selectedReason.value = reason
        _errorMessage.value = null
    }

    fun updateComments(value: String) {
        _comments.value = value
    }

    fun setAlsoBlockUser(value: Boolean) {
        _alsoBlockUser.value = value
    }

    /**
     * Report submit is UI-only. Blocking uses the live block API when requested.
     */
    suspend fun submit(
        authorUsername: String? = null,
        blocksRepository: BlocksRepository? = null,
        onUnauthorized: () -> Unit = {},
    ): Boolean {
        if (_selectedReason.value == null) {
            _errorMessage.value = "Choose a reason before submitting."
            return false
        }

        if (_alsoBlockUser.value) {
            val username = authorUsername?.trim().orEmpty()
            if (username.isEmpty() || blocksRepository == null) {
                _errorMessage.value = "We couldn't block this user."
                return false
            }

            _isSubmitting.value = true
            _errorMessage.value = null
            try {
                blocksRepository.blockUser(username)
            } catch (_: ApiException.Unauthorized) {
                onUnauthorized()
                _errorMessage.value = "We couldn't block this user."
                return false
            } catch (error: Exception) {
                val description = error.message?.trim().orEmpty()
                _errorMessage.value = description.ifEmpty { "We couldn't block this user." }
                return false
            } finally {
                _isSubmitting.value = false
            }
        }

        _errorMessage.value = null
        return true
    }
}

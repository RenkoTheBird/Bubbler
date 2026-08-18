package com.bubbler.android.features.report

import com.bubbler.android.data.model.ReportReason
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Report-post form state — mirrors Swift `ReportPostViewModel`.
 *
 * Submit is UI-only until the review-queue API lands.
 */
class ReportPostViewModel {
    private val _selectedReason = MutableStateFlow<ReportReason?>(null)
    val selectedReason: StateFlow<ReportReason?> = _selectedReason.asStateFlow()

    private val _comments = MutableStateFlow("")
    val comments: StateFlow<String> = _comments.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    val canSubmit: Boolean
        get() = _selectedReason.value != null

    fun selectReason(reason: ReportReason) {
        _selectedReason.value = reason
        _errorMessage.value = null
    }

    fun updateComments(value: String) {
        _comments.value = value
    }

    /** UI-only submit. The review-queue API is not wired yet. */
    fun submit(): Boolean {
        if (_selectedReason.value == null) {
            _errorMessage.value = "Choose a reason before submitting."
            return false
        }
        _errorMessage.value = null
        return true
    }
}

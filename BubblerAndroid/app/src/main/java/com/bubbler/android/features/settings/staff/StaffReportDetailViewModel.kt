package com.bubbler.android.features.settings.staff

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.StaffReport
import com.bubbler.android.data.model.StaffReportStatus
import com.bubbler.android.data.repository.StaffReportsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Single staff ticket — mirrors Swift `StaffReportDetailViewModel`. */
class StaffReportDetailViewModel(
    private val reportId: String,
    private val authSession: AuthSession,
    private val staffReportsRepository: StaffReportsRepository,
    initialReport: StaffReport? = null,
) : ViewModel() {
    private val _report = MutableStateFlow(initialReport)
    val report: StateFlow<StaffReport?> = _report.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isUpdating = MutableStateFlow(false)
    val isUpdating: StateFlow<Boolean> = _isUpdating.asStateFlow()

    private val _errorTitle = MutableStateFlow("Couldn't load report")
    val errorTitle: StateFlow<String> = _errorTitle.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun load(force: Boolean = false) {
        viewModelScope.launch { loadInternal(force = force) }
    }

    suspend fun loadAwait(force: Boolean = false) = loadInternal(force = force)

    fun updateStatus(status: StaffReportStatus) {
        viewModelScope.launch { updateStatusInternal(status) }
    }

    suspend fun updateStatusAwait(status: StaffReportStatus) = updateStatusInternal(status)

    fun updateLegalHold(legalHold: Boolean) {
        viewModelScope.launch { updateLegalHoldInternal(legalHold) }
    }

    suspend fun updateLegalHoldAwait(legalHold: Boolean) = updateLegalHoldInternal(legalHold)

    private suspend fun loadInternal(force: Boolean) {
        if (_report.value != null && !force) return

        _isLoading.value = true
        _errorTitle.value = "Couldn't load report"
        _errorMessage.value = null

        try {
            _report.value = staffReportsRepository.getReport(reportId)
        } catch (e: Exception) {
            handleSessionError(e, fallbackMessage = "We couldn't load this report.")
        }

        _isLoading.value = false
    }

    private suspend fun updateStatusInternal(status: StaffReportStatus) {
        if (_isUpdating.value) return

        _isUpdating.value = true
        _errorTitle.value = "Couldn't update report"
        _errorMessage.value = null

        try {
            _report.value = staffReportsRepository.updateStatus(reportId, status)
        } catch (e: Exception) {
            handleSessionError(
                e,
                fallbackMessage = "We couldn't update this report's status.",
            )
        }

        _isUpdating.value = false
    }

    private suspend fun updateLegalHoldInternal(legalHold: Boolean) {
        if (_isUpdating.value) return

        _isUpdating.value = true
        _errorTitle.value = "Couldn't update legal hold"
        _errorMessage.value = null

        try {
            _report.value = staffReportsRepository.updateLegalHold(reportId, legalHold)
        } catch (e: Exception) {
            handleSessionError(
                e,
                fallbackMessage = "We couldn't update this report's legal hold.",
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

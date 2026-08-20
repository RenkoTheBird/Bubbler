package com.bubbler.android.features.settings.staff

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.StaffReport
import com.bubbler.android.data.model.StaffReportReasonFilter
import com.bubbler.android.data.model.StaffReportStatus
import com.bubbler.android.data.repository.StaffReportsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Staff report queue list — mirrors Swift `StaffReportsViewModel`. */
class StaffReportsViewModel(
    private val authSession: AuthSession,
    private val staffReportsRepository: StaffReportsRepository,
) : ViewModel() {
    private val _reports = MutableStateFlow<List<StaffReport>>(emptyList())
    val reports: StateFlow<List<StaffReport>> = _reports.asStateFlow()

    private val _selectedStatus = MutableStateFlow(StaffReportStatus.OPEN)
    val selectedStatus: StateFlow<StaffReportStatus> = _selectedStatus.asStateFlow()

    private val _selectedReason = MutableStateFlow(StaffReportReasonFilter.ALL)
    val selectedReason: StateFlow<StaffReportReasonFilter> = _selectedReason.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorTitle = MutableStateFlow("Couldn't load reports")
    val errorTitle: StateFlow<String> = _errorTitle.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun loadReports(force: Boolean = true) {
        viewModelScope.launch { loadReportsInternal(force = force) }
    }

    suspend fun loadReportsAwait(force: Boolean = true) = loadReportsInternal(force = force)

    fun changeStatusFilter(status: StaffReportStatus) {
        if (_selectedStatus.value == status && _reports.value.isNotEmpty()) return
        _selectedStatus.value = status
        viewModelScope.launch { loadReportsInternal(force = true) }
    }

    suspend fun changeStatusFilterAwait(status: StaffReportStatus) {
        _selectedStatus.value = status
        loadReportsInternal(force = true)
    }

    fun changeReasonFilter(reason: StaffReportReasonFilter) {
        if (_selectedReason.value == reason && _reports.value.isNotEmpty()) return
        _selectedReason.value = reason
        viewModelScope.launch { loadReportsInternal(force = true) }
    }

    suspend fun changeReasonFilterAwait(reason: StaffReportReasonFilter) {
        _selectedReason.value = reason
        loadReportsInternal(force = true)
    }

    private suspend fun loadReportsInternal(force: Boolean) {
        if (!force && _reports.value.isNotEmpty()) return

        _isLoading.value = true
        _errorTitle.value = "Couldn't load reports"
        _errorMessage.value = null

        try {
            _reports.value = staffReportsRepository.listReports(
                status = _selectedStatus.value,
                reason = _selectedReason.value,
            )
        } catch (e: Exception) {
            handleSessionError(e, fallbackMessage = "We couldn't load the report queue.")
        }

        _isLoading.value = false
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

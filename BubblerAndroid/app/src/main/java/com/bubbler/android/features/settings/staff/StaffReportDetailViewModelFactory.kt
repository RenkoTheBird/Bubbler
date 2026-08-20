package com.bubbler.android.features.settings.staff

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.model.StaffReport
import com.bubbler.android.data.repository.StaffReportsRepository

class StaffReportDetailViewModelFactory(
    private val reportId: String,
    private val authSession: AuthSession,
    private val staffReportsRepository: StaffReportsRepository,
    private val initialReport: StaffReport? = null,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(StaffReportDetailViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return StaffReportDetailViewModel(
            reportId = reportId,
            authSession = authSession,
            staffReportsRepository = staffReportsRepository,
            initialReport = initialReport,
        ) as T
    }
}

package com.bubbler.android.features.settings.staff

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.StaffReportsRepository

class StaffReportsViewModelFactory(
    private val authSession: AuthSession,
    private val staffReportsRepository: StaffReportsRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(StaffReportsViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return StaffReportsViewModel(
            authSession = authSession,
            staffReportsRepository = staffReportsRepository,
        ) as T
    }
}

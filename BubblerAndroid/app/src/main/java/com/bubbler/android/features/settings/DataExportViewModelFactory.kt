package com.bubbler.android.features.settings

import android.content.ContentResolver
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession

class DataExportViewModelFactory(
    private val authSession: AuthSession,
    private val contentResolver: ContentResolver,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(DataExportViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return DataExportViewModel(
            authSession = authSession,
            contentResolver = contentResolver,
        ) as T
    }
}

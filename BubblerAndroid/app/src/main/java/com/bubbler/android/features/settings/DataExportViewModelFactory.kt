package com.bubbler.android.features.settings

import android.content.ContentResolver
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.UserRepository

class DataExportViewModelFactory(
    private val authSession: AuthSession,
    private val contentResolver: ContentResolver,
    private val userRepository: UserRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(DataExportViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return DataExportViewModel(
            authSession = authSession,
            contentResolver = contentResolver,
            userRepository = userRepository,
        ) as T
    }
}

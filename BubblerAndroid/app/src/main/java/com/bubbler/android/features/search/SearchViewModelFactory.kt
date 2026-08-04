package com.bubbler.android.features.search

import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.SearchRepository

class SearchViewModelFactory(
    private val authSession: AuthSession,
    private val searchRepository: SearchRepository,
    private val prefs: SharedPreferences,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(SearchViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return SearchViewModel(
            authSession = authSession,
            searchRepository = searchRepository,
            prefs = prefs,
        ) as T
    }
}

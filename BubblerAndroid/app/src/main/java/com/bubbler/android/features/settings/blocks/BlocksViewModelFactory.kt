package com.bubbler.android.features.settings.blocks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.data.repository.BlocksRepository

class BlocksViewModelFactory(
    private val authSession: AuthSession,
    private val blocksRepository: BlocksRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(BlocksViewModel::class.java)) {
            "Unknown ViewModel class: ${modelClass.name}"
        }
        return BlocksViewModel(
            authSession = authSession,
            blocksRepository = blocksRepository,
        ) as T
    }
}

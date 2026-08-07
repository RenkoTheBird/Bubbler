package com.bubbler.android.features.settings

import android.content.ContentResolver
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.core.storage.DataExportWriter
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Account data export — mirrors iOS `DataExportViewModel`.
 * Fetches pretty-printed JSON, then saves via SAF Create Document.
 */
class DataExportViewModel(
    private val authSession: AuthSession,
    private val contentResolver: ContentResolver,
    private val userRepository: UserRepository,
) : ViewModel() {
    private val _isExporting = MutableStateFlow(false)
    val isExporting: StateFlow<Boolean> = _isExporting.asStateFlow()

    private val _errorTitle = MutableStateFlow("Couldn't export data")
    val errorTitle: StateFlow<String> = _errorTitle.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    /** One-shot suggested filenames for [ActivityResultContracts.CreateDocument]. */
    private val _createDocumentRequests = MutableSharedFlow<String>(extraBufferCapacity = 1)
    val createDocumentRequests: SharedFlow<String> = _createDocumentRequests.asSharedFlow()

    private var pendingJsonBytes: ByteArray? = null

    /** Fetches pretty-printed JSON, then launches the SAF save picker. */
    fun startExport() {
        if (_isExporting.value) return

        viewModelScope.launch {
            _isExporting.value = true
            _errorTitle.value = "Couldn't export data"
            _errorMessage.value = null
            pendingJsonBytes = null

            try {
                val bytes = userRepository.exportUserData()
                pendingJsonBytes = bytes
                _createDocumentRequests.emit(DataExportWriter.suggestedFileName())
            } catch (e: Exception) {
                pendingJsonBytes = null
                _isExporting.value = false
                handleSessionError(
                    e,
                    fallbackMessage = "We couldn't prepare your data export. Please try again.",
                )
            }
        }
    }

    /** Called when the user picks a save location (or cancels) in the SAF picker. */
    fun onSaveLocationChosen(uri: Uri?) {
        if (uri == null) {
            cancelPendingSave()
            return
        }

        val bytes = pendingJsonBytes
        if (bytes == null) {
            _isExporting.value = false
            return
        }

        viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    DataExportWriter.writeJson(contentResolver, uri, bytes)
                }
                pendingJsonBytes = null
            } catch (e: Exception) {
                handleSessionError(
                    e,
                    fallbackMessage = "We couldn't save your data export. Please try again.",
                )
            } finally {
                _isExporting.value = false
            }
        }
    }

    fun dismissError() {
        _errorMessage.value = null
    }

    private fun cancelPendingSave() {
        pendingJsonBytes = null
        _isExporting.value = false
    }

    private fun handleSessionError(error: Exception, fallbackMessage: String) {
        if (error is ApiException.Unauthorized) {
            authSession.signOut()
        }
        val description = error.message?.trim().orEmpty()
        _errorMessage.value = description.ifEmpty { fallbackMessage }
    }
}

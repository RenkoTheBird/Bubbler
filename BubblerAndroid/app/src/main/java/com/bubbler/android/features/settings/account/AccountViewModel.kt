package com.bubbler.android.features.settings.account

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.User
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Consolidated account settings ViewModel — replaces Swift
 * `ProfileInformationViewModel`, `EmailSettingsViewModel`,
 * `PasswordSecurityViewModel`, and `DeleteAccountViewModel`.
 */
class AccountViewModel(
    private val authSession: AuthSession,
    private val userRepository: UserRepository,
    private val authRepository: AuthRepository,
) : ViewModel() {
    private val _profile = MutableStateFlow<User?>(null)
    val profile: StateFlow<User?> = _profile.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _isDeleting = MutableStateFlow(false)
    val isDeleting: StateFlow<Boolean> = _isDeleting.asStateFlow()

    private val _errorTitle = MutableStateFlow("Couldn't load account")
    val errorTitle: StateFlow<String> = _errorTitle.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _successMessage = MutableStateFlow<String?>(null)
    val successMessage: StateFlow<String?> = _successMessage.asStateFlow()

    // Email settings
    private val _email = MutableStateFlow("")
    val email: StateFlow<String> = _email.asStateFlow()

    private val _currentEmail = MutableStateFlow("")
    val currentEmail: StateFlow<String> = _currentEmail.asStateFlow()

    // Password settings
    private val _emailOrUsername = MutableStateFlow("")
    val emailOrUsername: StateFlow<String> = _emailOrUsername.asStateFlow()

    private val _currentPassword = MutableStateFlow("")
    val currentPassword: StateFlow<String> = _currentPassword.asStateFlow()

    private val _newPassword = MutableStateFlow("")
    val newPassword: StateFlow<String> = _newPassword.asStateFlow()

    private val _confirmNewPassword = MutableStateFlow("")
    val confirmNewPassword: StateFlow<String> = _confirmNewPassword.asStateFlow()

    private val _accountUsername = MutableStateFlow("")
    val accountUsername: StateFlow<String> = _accountUsername.asStateFlow()

    // Delete account
    private val _deletePassword = MutableStateFlow("")
    val deletePassword: StateFlow<String> = _deletePassword.asStateFlow()

    private var hasLoaded = false

    val memberSinceText: String
        get() {
            val createdAt = _profile.value?.createdAt ?: return "—"
            return MEMBER_SINCE_FORMATTER.format(
                createdAt.atZone(ZoneId.systemDefault()).toLocalDate(),
            )
        }

    val canSaveEmail: Boolean
        get() {
            val trimmed = _email.value.trim()
            return trimmed.isNotEmpty() &&
                !trimmed.equals(_currentEmail.value, ignoreCase = true) &&
                !_isSaving.value &&
                !_isLoading.value
        }

    val canResetPassword: Boolean
        get() = _emailOrUsername.value.trim().isNotEmpty() &&
            _currentPassword.value.isNotEmpty() &&
            _newPassword.value.isNotEmpty() &&
            _confirmNewPassword.value.isNotEmpty() &&
            !_isSaving.value &&
            !_isLoading.value

    val canDeleteAccount: Boolean
        get() = _deletePassword.value.isNotEmpty() &&
            _currentEmail.value.isNotEmpty() &&
            !_isDeleting.value &&
            !_isLoading.value

    fun updateEmail(value: String) {
        _email.value = value
    }

    fun updateEmailOrUsername(value: String) {
        _emailOrUsername.value = value
    }

    fun updateCurrentPassword(value: String) {
        _currentPassword.value = value
    }

    fun updateNewPassword(value: String) {
        _newPassword.value = value
    }

    fun updateConfirmNewPassword(value: String) {
        _confirmNewPassword.value = value
    }

    fun updateDeletePassword(value: String) {
        _deletePassword.value = value
    }

    fun loadProfile(
        force: Boolean = false,
        loadErrorTitle: String = "Couldn't load account",
    ) {
        if (!force && hasLoaded) return
        viewModelScope.launch {
            loadProfileInternal(force = force, loadErrorTitle = loadErrorTitle)
        }
    }

    /** Test / awaitable entry — same work as [loadProfile]. */
    suspend fun loadProfileAwait(
        force: Boolean = false,
        loadErrorTitle: String = "Couldn't load account",
    ) {
        loadProfileInternal(force = force, loadErrorTitle = loadErrorTitle)
    }

    fun reloadProfile(loadErrorTitle: String = "Couldn't load account") {
        hasLoaded = false
        loadProfile(force = true, loadErrorTitle = loadErrorTitle)
    }

    fun saveEmail() {
        viewModelScope.launch { saveEmailInternal() }
    }

    suspend fun saveEmailAwait() = saveEmailInternal()

    fun resetPassword() {
        viewModelScope.launch { resetPasswordInternal() }
    }

    suspend fun resetPasswordAwait() = resetPasswordInternal()

    fun deleteAccount() {
        viewModelScope.launch { deleteAccountInternal() }
    }

    suspend fun deleteAccountAwait() = deleteAccountInternal()

    private suspend fun loadProfileInternal(
        force: Boolean,
        loadErrorTitle: String,
    ) {
        if (!force && hasLoaded) return

        _isLoading.value = true
        _errorTitle.value = loadErrorTitle
        _errorMessage.value = null
        _successMessage.value = null

        try {
            val profile = userRepository.getProfile()
            applyProfile(profile)
            hasLoaded = true
        } catch (e: Exception) {
            handleSessionError(e, fallbackMessage = "We couldn't load your account details.")
        }

        _isLoading.value = false
    }

    private suspend fun saveEmailInternal() {
        val trimmed = _email.value.trim()
        if (trimmed.isEmpty()) {
            _errorTitle.value = "Couldn't update email"
            _errorMessage.value = "Enter a valid email address."
            return
        }

        _isSaving.value = true
        _errorTitle.value = "Couldn't update email"
        _errorMessage.value = null
        _successMessage.value = null

        try {
            val profile = userRepository.updateEmail(trimmed)
            applyProfile(profile)
            _successMessage.value = "Your email was updated successfully."
        } catch (e: Exception) {
            handleSessionError(e, fallbackMessage = "We couldn't update your email.")
        }

        _isSaving.value = false
    }

    private suspend fun resetPasswordInternal() {
        val identity = _emailOrUsername.value.trim()

        when {
            identity.isEmpty() -> {
                _errorTitle.value = "Couldn't reset password"
                _errorMessage.value = "Enter your current email or username."
                return
            }
            _currentPassword.value.isEmpty() -> {
                _errorTitle.value = "Couldn't reset password"
                _errorMessage.value = "Enter your current password."
                return
            }
            _newPassword.value.length < 5 -> {
                _errorTitle.value = "Couldn't reset password"
                _errorMessage.value = "New password must be at least 5 characters."
                return
            }
            _newPassword.value.length > 40 -> {
                _errorTitle.value = "Couldn't reset password"
                _errorMessage.value = "New password must be 40 characters or fewer."
                return
            }
            _newPassword.value != _confirmNewPassword.value -> {
                _errorTitle.value = "Couldn't reset password"
                _errorMessage.value = "New passwords do not match."
                return
            }
            _newPassword.value == _currentPassword.value -> {
                _errorTitle.value = "Couldn't reset password"
                _errorMessage.value =
                    "New password must be different from your current password."
                return
            }
        }

        _isSaving.value = true
        _errorTitle.value = "Couldn't reset password"
        _errorMessage.value = null

        try {
            userRepository.updatePassword(
                emailOrUsername = identity,
                currentPassword = _currentPassword.value,
                newPassword = _newPassword.value,
                confirmNewPassword = _confirmNewPassword.value,
            )
            authSession.signOut()
            authSession.showSuccessMessage("Password updated. Please log in with your new password.")
        } catch (e: Exception) {
            handleSessionError(
                e,
                fallbackMessage = "We couldn't reset your password. Please try again.",
            )
        }

        _isSaving.value = false
    }

    private suspend fun deleteAccountInternal() {
        if (_deletePassword.value.isEmpty()) {
            _errorTitle.value = "Couldn't delete account"
            _errorMessage.value = "Enter your password to confirm."
            return
        }
        if (_currentEmail.value.isEmpty()) {
            _errorTitle.value = "Couldn't delete account"
            _errorMessage.value =
                "We couldn't confirm your account email. Try reloading this screen."
            return
        }

        _isDeleting.value = true
        _errorTitle.value = "Couldn't delete account"
        _errorMessage.value = null

        try {
            try {
                authRepository.login(
                    email = _currentEmail.value,
                    password = _deletePassword.value,
                )
            } catch (e: ApiException.Unauthorized) {
                _deletePassword.value = ""
                _errorMessage.value = "Incorrect password. Please try again."
                _isDeleting.value = false
                return
            } catch (e: Exception) {
                val description = e.message?.trim().orEmpty()
                _errorMessage.value = if (description.isEmpty()) {
                    "We couldn't verify your password. Please try again."
                } else {
                    description
                }
                _isDeleting.value = false
                return
            }

            userRepository.deleteAccount()
            authSession.signOut()
        } catch (e: Exception) {
            handleSessionError(
                e,
                fallbackMessage = "We couldn't delete your account. Please try again.",
            )
        }

        _isDeleting.value = false
    }

    private fun applyProfile(profile: User) {
        _profile.value = profile
        val email = profile.email.orEmpty()
        _currentEmail.value = email
        _email.value = email
        _accountUsername.value = profile.username
    }

    private fun handleSessionError(error: Exception, fallbackMessage: String) {
        if (error is ApiException.Unauthorized) {
            authSession.signOut()
        }
        val description = error.message?.trim().orEmpty()
        _errorMessage.value = description.ifEmpty { fallbackMessage }
    }

    companion object {
        private val MEMBER_SINCE_FORMATTER: DateTimeFormatter =
            DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)
    }
}

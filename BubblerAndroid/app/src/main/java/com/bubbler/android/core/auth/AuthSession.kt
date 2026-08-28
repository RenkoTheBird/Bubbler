package com.bubbler.android.core.auth

import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.AuthResponse
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.time.LocalDate
import java.time.Period
import java.util.Base64

object AgeGate {
    /** Global floor (EU-friendly GDPR Art. 8). */
    const val MINIMUM_AGE: Int = 16

    fun age(from: LocalDate, on: LocalDate = LocalDate.now()): Int =
        Period.between(from, on).years

    fun isOldEnough(dateOfBirth: LocalDate, on: LocalDate = LocalDate.now()): Boolean =
        age(from = dateOfBirth, on = on) >= MINIMUM_AGE

    val underageMessage: String
        get() = "You must be at least $MINIMUM_AGE years old to use Bubbler."
}

enum class OnboardingGate {
    Unknown,
    Required,
    Complete,
}

/**
 * Session gate matching iOS AuthSession: restore token, sign-in/register, sign-out.
 */
class AuthSession(
    private val tokenStore: TokenStore,
    private val authRepository: AuthRepository,
    private val userRepository: UserRepository? = null,
    private val preferencesRepository: PreferencesRepository? = null,
) {
    private val _accessToken = MutableStateFlow(tokenStore.loadAccessToken())
    val accessToken: StateFlow<String?> = _accessToken.asStateFlow()

    private val _userId = MutableStateFlow(restoredUserId(from = _accessToken.value))
    val userId: StateFlow<Int?> = _userId.asStateFlow()

    private val _isStaff = MutableStateFlow(false)
    val isStaff: StateFlow<Boolean> = _isStaff.asStateFlow()

    private val _authError = MutableStateFlow<String?>(null)
    val authError: StateFlow<String?> = _authError.asStateFlow()

    private val _successMessage = MutableStateFlow<String?>(null)
    val successMessage: StateFlow<String?> = _successMessage.asStateFlow()

    private val _isWorking = MutableStateFlow(false)
    val isWorking: StateFlow<Boolean> = _isWorking.asStateFlow()

    private val _onboardingGate = MutableStateFlow(OnboardingGate.Unknown)
    val onboardingGate: StateFlow<OnboardingGate> = _onboardingGate.asStateFlow()

    val isSignedIn: Boolean
        get() = _accessToken.value != null

    suspend fun signIn(email: String, password: String) {
        val trimmedEmail = normalizedEmail(email)

        when {
            trimmedEmail.isEmpty() -> {
                _authError.value = "Enter your email address."
                return
            }
            password.isEmpty() -> {
                _authError.value = "Enter your password."
                return
            }
        }

        performAuthAction(unauthorizedErrorMessage = "Incorrect username or password.") {
            authRepository.login(email = trimmedEmail, password = password)
        }
    }

    suspend fun createAccount(
        username: String,
        email: String,
        password: String,
        confirmPassword: String,
        dateOfBirth: LocalDate,
    ) {
        val trimmedUsername = username.trim()
        val trimmedEmail = normalizedEmail(email)

        when {
            trimmedUsername.isEmpty() -> {
                _authError.value = "Enter a username."
                return
            }
            trimmedUsername.length > 20 -> {
                _authError.value = "Username must be 20 characters or fewer."
                return
            }
            trimmedEmail.isEmpty() -> {
                _authError.value = "Enter your email address."
                return
            }
            !AgeGate.isOldEnough(dateOfBirth) -> {
                _authError.value = AgeGate.underageMessage
                return
            }
            password.length < 5 -> {
                _authError.value = "Password must be at least 5 characters."
                return
            }
            password.length > 40 -> {
                _authError.value = "Password must be 40 characters or fewer."
                return
            }
            password != confirmPassword -> {
                _authError.value = "Passwords do not match."
                return
            }
        }

        val didCreateAccount = performAuthAction {
            authRepository.register(
                username = trimmedUsername,
                email = trimmedEmail,
                password = password,
                dateOfBirth = dateOfBirth,
            )
        }

        if (didCreateAccount) {
            _successMessage.value = "Account created successfully!"
        }
    }

    suspend fun refreshStaffAccess() {
        if (!isSignedIn) {
            _isStaff.value = false
            return
        }
        val repo = userRepository ?: return
        try {
            _isStaff.value = repo.getProfile().isStaff
        } catch (e: ApiException.Unauthorized) {
            signOut()
        } catch (_: Exception) {
            // Keep the last known staff flag on transient failures.
        }
    }

    suspend fun refreshOnboardingStatus() {
        if (!isSignedIn) {
            _onboardingGate.value = OnboardingGate.Unknown
            return
        }
        val repo = preferencesRepository ?: run {
            _onboardingGate.value = OnboardingGate.Complete
            return
        }
        try {
            val preferences = repo.getPreferences()
            _onboardingGate.value = if (preferences.onboardingCompleted) {
                OnboardingGate.Complete
            } else {
                OnboardingGate.Required
            }
        } catch (e: ApiException.Unauthorized) {
            signOut()
        } catch (_: Exception) {
            _onboardingGate.value = OnboardingGate.Complete
        }
    }

    fun markOnboardingComplete() {
        _onboardingGate.value = OnboardingGate.Complete
    }

    fun signOut() {
        tokenStore.deleteAccessToken()
        _accessToken.value = null
        _userId.value = null
        _isStaff.value = false
        _onboardingGate.value = OnboardingGate.Unknown
        _authError.value = null
        _successMessage.value = null
    }

    fun clearSuccessMessage() {
        _successMessage.value = null
    }

    fun showSuccessMessage(message: String) {
        _successMessage.value = message
    }

    private suspend fun performAuthAction(
        unauthorizedErrorMessage: String? = null,
        action: suspend () -> AuthResponse,
    ): Boolean {
        _authError.value = null
        _successMessage.value = null
        _isWorking.value = true
        try {
            val response = action()
            tokenStore.saveAccessToken(response.accessToken)
            _accessToken.value = response.accessToken
            _userId.value = response.userId
            refreshStaffAccess()
            return true
        } catch (e: ApiException.Unauthorized) {
            _authError.value = unauthorizedErrorMessage ?: e.message
            return false
        } catch (e: Exception) {
            _authError.value = e.message ?: "Something went wrong."
            return false
        } finally {
            _isWorking.value = false
        }
    }

    private fun normalizedEmail(email: String): String =
        email.trim().lowercase()

    companion object {
        private val jwtJson = Json { ignoreUnknownKeys = true }

        fun restoredUserId(from: String?): Int? {
            if (from.isNullOrBlank()) return null

            val segments = from.split('.')
            if (segments.size < 2) return null

            var payload = segments[1]
                .replace('-', '+')
                .replace('_', '/')
            val padding = (4 - payload.length % 4) % 4
            if (padding > 0) {
                payload += "=".repeat(padding)
            }

            return try {
                val bytes = Base64.getDecoder().decode(payload)
                val root = jwtJson.parseToJsonElement(bytes.decodeToString()).jsonObject
                val subject = root["sub"]?.jsonPrimitive?.contentOrNull ?: return null
                subject.toIntOrNull()
            } catch (_: Exception) {
                null
            }
        }
    }
}

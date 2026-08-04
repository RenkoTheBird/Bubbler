package com.bubbler.android.features.settings.account

import android.content.SharedPreferences
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.User
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.AuthResponse
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant
import java.util.Base64

class AccountViewModelTest {
    private lateinit var userRepository: FakeUserRepository
    private lateinit var authRepository: FakeAuthRepository
    private lateinit var authSession: AuthSession
    private lateinit var viewModel: AccountViewModel
    private val now: Instant = Instant.parse("2026-08-03T12:00:00Z")

    @Before
    fun setUp() {
        userRepository = FakeUserRepository()
        authRepository = FakeAuthRepository()
        authSession = signedInSession(userId = 42)
        viewModel = AccountViewModel(
            authSession = authSession,
            userRepository = userRepository,
            authRepository = authRepository,
        )
    }

    @Test
    fun loadProfile_populatesEmailAndUsername() = runTest {
        userRepository.myProfile = user(email = "me@bubbler.test", username = "me")

        viewModel.loadProfileAwait()

        assertEquals("me", viewModel.profile.value?.username)
        assertEquals("me@bubbler.test", viewModel.currentEmail.value)
        assertEquals("me@bubbler.test", viewModel.email.value)
        assertEquals("me", viewModel.accountUsername.value)
        assertFalse(viewModel.isLoading.value)
        assertNull(viewModel.errorMessage.value)
    }

    @Test
    fun saveEmail_updatesCurrentEmail() = runTest {
        userRepository.myProfile = user(email = "old@bubbler.test", username = "me")
        viewModel.loadProfileAwait()
        viewModel.updateEmail("new@bubbler.test")
        userRepository.updatedEmailProfile = user(email = "new@bubbler.test", username = "me")

        viewModel.saveEmailAwait()

        assertEquals("new@bubbler.test", viewModel.currentEmail.value)
        assertEquals("Your email was updated successfully.", viewModel.successMessage.value)
        assertEquals("new@bubbler.test", userRepository.lastEmailUpdate)
    }

    @Test
    fun resetPassword_rejectsMismatchedConfirmation() = runTest {
        userRepository.myProfile = user(email = "me@bubbler.test", username = "me")
        viewModel.loadProfileAwait()
        viewModel.updateEmailOrUsername("me@bubbler.test")
        viewModel.updateCurrentPassword("oldpass")
        viewModel.updateNewPassword("newpass")
        viewModel.updateConfirmNewPassword("different")

        viewModel.resetPasswordAwait()

        assertEquals("Couldn't reset password", viewModel.errorTitle.value)
        assertEquals("New passwords do not match.", viewModel.errorMessage.value)
        assertFalse(userRepository.passwordUpdated)
        assertTrue(authSession.isSignedIn)
    }

    @Test
    fun resetPassword_success_signsOutWithMessage() = runTest {
        userRepository.myProfile = user(email = "me@bubbler.test", username = "me")
        viewModel.loadProfileAwait()
        viewModel.updateEmailOrUsername("me@bubbler.test")
        viewModel.updateCurrentPassword("oldpass")
        viewModel.updateNewPassword("newpass")
        viewModel.updateConfirmNewPassword("newpass")

        viewModel.resetPasswordAwait()

        assertTrue(userRepository.passwordUpdated)
        assertNull(authSession.accessToken.value)
        assertEquals(
            "Password updated. Please log in with your new password.",
            authSession.successMessage.value,
        )
    }

    @Test
    fun deleteAccount_wrongPassword_clearsField() = runTest {
        userRepository.myProfile = user(email = "me@bubbler.test", username = "me")
        viewModel.loadProfileAwait()
        viewModel.updateDeletePassword("wrong")
        authRepository.failWith = ApiException.Unauthorized

        viewModel.deleteAccountAwait()

        assertEquals("", viewModel.deletePassword.value)
        assertEquals("Incorrect password. Please try again.", viewModel.errorMessage.value)
        assertFalse(userRepository.accountDeleted)
        assertTrue(authSession.isSignedIn)
    }

    @Test
    fun deleteAccount_success_deletesAndSignsOut() = runTest {
        userRepository.myProfile = user(email = "me@bubbler.test", username = "me")
        viewModel.loadProfileAwait()
        viewModel.updateDeletePassword("correct")

        viewModel.deleteAccountAwait()

        assertTrue(authRepository.loginCalled)
        assertTrue(userRepository.accountDeleted)
        assertNull(authSession.accessToken.value)
    }

    @Test
    fun loadProfile_unauthorized_signsOut() = runTest {
        userRepository.failWith = ApiException.Unauthorized

        viewModel.loadProfileAwait()

        assertNull(authSession.accessToken.value)
        assertEquals("Your session has expired. Please log in again.", viewModel.errorMessage.value)
    }

    private fun user(
        email: String,
        username: String,
        id: Int = 42,
    ) = User(
        id = id,
        username = username,
        email = email,
        createdAt = now,
    )

    private fun signedInSession(userId: Int): AuthSession {
        val store = TokenStore(MemoryPrefs())
        store.saveAccessToken(jwtForUser(userId))
        return AuthSession(
            tokenStore = store,
            authRepository = AuthRepository(ApiClient(baseUrl = "http://localhost")),
        )
    }

    private fun jwtForUser(userId: Int): String {
        val header = Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"alg":"none"}""".toByteArray())
        val payload = Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"sub":"$userId"}""".toByteArray())
        return "$header.$payload.sig"
    }

    private class FakeUserRepository : UserRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        var myProfile: User? = null
        var updatedEmailProfile: User? = null
        var lastEmailUpdate: String? = null
        var passwordUpdated = false
        var accountDeleted = false
        var failWith: Exception? = null

        override suspend fun getProfile(): User {
            failWith?.let { throw it }
            return myProfile ?: error("myProfile not set")
        }

        override suspend fun updateEmail(email: String): User {
            failWith?.let { throw it }
            lastEmailUpdate = email
            return updatedEmailProfile ?: error("updatedEmailProfile not set")
        }

        override suspend fun updatePassword(
            emailOrUsername: String,
            currentPassword: String,
            newPassword: String,
            confirmNewPassword: String,
        ) {
            failWith?.let { throw it }
            passwordUpdated = true
        }

        override suspend fun deleteAccount() {
            failWith?.let { throw it }
            accountDeleted = true
        }
    }

    private class FakeAuthRepository : AuthRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
    ) {
        var loginCalled = false
        var failWith: Exception? = null

        override suspend fun login(email: String, password: String): AuthResponse {
            failWith?.let { throw it }
            loginCalled = true
            return AuthResponse(
                accessToken = "tok",
                tokenType = "bearer",
                userId = 42,
            )
        }
    }

    private class MemoryPrefs : SharedPreferences {
        private val map = mutableMapOf<String, String?>()

        override fun getAll(): MutableMap<String, *> = map.toMutableMap()
        override fun getString(key: String?, defValue: String?): String? =
            if (map.containsKey(key)) map[key] else defValue
        override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
            defValues
        override fun getInt(key: String?, defValue: Int): Int = defValue
        override fun getLong(key: String?, defValue: Long): Long = defValue
        override fun getFloat(key: String?, defValue: Float): Float = defValue
        override fun getBoolean(key: String?, defValue: Boolean): Boolean = defValue
        override fun contains(key: String?): Boolean = map.containsKey(key)

        override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
            private val pending = mutableMapOf<String, String?>()
            private val removals = mutableSetOf<String>()
            override fun putString(key: String?, value: String?): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }
            override fun putStringSet(key: String?, values: MutableSet<String>?) = this
            override fun putInt(key: String?, value: Int) = this
            override fun putLong(key: String?, value: Long) = this
            override fun putFloat(key: String?, value: Float) = this
            override fun putBoolean(key: String?, value: Boolean) = this
            override fun remove(key: String?): SharedPreferences.Editor {
                removals.add(key!!)
                return this
            }
            override fun clear(): SharedPreferences.Editor {
                map.clear()
                return this
            }
            override fun commit(): Boolean {
                removals.forEach { map.remove(it) }
                map.putAll(pending)
                pending.clear()
                removals.clear()
                return true
            }
            override fun apply() {
                commit()
            }
        }

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }
}

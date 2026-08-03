package com.bubbler.android.core.auth

import android.content.SharedPreferences
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.AuthResponse
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.util.Base64

class AuthSessionTest {
    private class MemoryPrefs : SharedPreferences {
        private val map = mutableMapOf<String, String?>()

        override fun getString(key: String?, defValue: String?): String? =
            if (map.containsKey(key)) map[key] else defValue

        override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
            private val pending = mutableMapOf<String, String?>()
            private val removals = mutableSetOf<String>()

            override fun putString(key: String?, value: String?): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }

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

            override fun putStringSet(key: String?, values: MutableSet<String>?) = this
            override fun putInt(key: String?, value: Int) = this
            override fun putLong(key: String?, value: Long) = this
            override fun putFloat(key: String?, value: Float) = this
            override fun putBoolean(key: String?, value: Boolean) = this
        }

        override fun getAll(): MutableMap<String, *> = map.toMutableMap()
        override fun getStringSet(key: String?, defValues: MutableSet<String>?) = defValues
        override fun getInt(key: String?, defValue: Int) = defValue
        override fun getLong(key: String?, defValue: Long) = defValue
        override fun getFloat(key: String?, defValue: Float) = defValue
        override fun getBoolean(key: String?, defValue: Boolean) = defValue
        override fun contains(key: String?) = map.containsKey(key)
        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }

    private class FakeAuthRepository(
        private val loginResult: Result<AuthResponse> = Result.success(
            AuthResponse(accessToken = fakeJwt(42), tokenType = "bearer", userId = 42),
        ),
        private val registerResult: Result<AuthResponse> = loginResult,
    ) : AuthRepository(ApiClient(baseUrl = "http://127.0.0.1")) {
        var lastLoginEmail: String? = null
        var lastRegisterDob: LocalDate? = null

        override suspend fun login(email: String, password: String): AuthResponse {
            lastLoginEmail = email
            return loginResult.getOrThrow()
        }

        override suspend fun register(
            username: String,
            email: String,
            password: String,
            dateOfBirth: LocalDate,
        ): AuthResponse {
            lastRegisterDob = dateOfBirth
            return registerResult.getOrThrow()
        }
    }

    @Test
    fun restoresUserIdFromStoredToken() {
        val token = fakeJwt(17)
        val store = TokenStore(MemoryPrefs())
        store.saveAccessToken(token)

        val session = AuthSession(tokenStore = store, authRepository = FakeAuthRepository())

        assertTrue(session.isSignedIn)
        assertEquals(token, session.accessToken.value)
        assertEquals(17, session.userId.value)
    }

    @Test
    fun signIn_validatesAndPersists() = runTest {
        val store = TokenStore(MemoryPrefs())
        val repo = FakeAuthRepository()
        val session = AuthSession(store, repo)

        session.signIn(email = "  A@B.Com ", password = "secret")

        assertEquals("a@b.com", repo.lastLoginEmail)
        assertEquals(42, session.userId.value)
        assertEquals(store.loadAccessToken(), session.accessToken.value)
        assertNull(session.authError.value)
    }

    @Test
    fun signIn_emptyEmail_setsError() = runTest {
        val session = AuthSession(TokenStore(MemoryPrefs()), FakeAuthRepository())
        session.signIn(email = "  ", password = "x")
        assertEquals("Enter your email address.", session.authError.value)
        assertFalse(session.isSignedIn)
    }

    @Test
    fun createAccount_rejectsUnderage() = runTest {
        val session = AuthSession(TokenStore(MemoryPrefs()), FakeAuthRepository())
        session.createAccount(
            username = "kid",
            email = "kid@example.com",
            password = "secret",
            confirmPassword = "secret",
            dateOfBirth = LocalDate.now().minusYears(10),
        )
        assertEquals(AgeGate.underageMessage, session.authError.value)
        assertFalse(session.isSignedIn)
    }

    @Test
    fun createAccount_success_setsMessageAndDobCalendarDay() = runTest {
        val store = TokenStore(MemoryPrefs())
        val repo = FakeAuthRepository()
        val session = AuthSession(store, repo)
        val dob = LocalDate.of(1998, 3, 4)

        session.createAccount(
            username = "wren",
            email = "wren@example.com",
            password = "secret",
            confirmPassword = "secret",
            dateOfBirth = dob,
        )

        assertEquals(dob, repo.lastRegisterDob)
        assertTrue(session.isSignedIn)
        assertEquals("Account created successfully!", session.successMessage.value)
    }

    @Test
    fun signOut_clearsTokenAndState() = runTest {
        val store = TokenStore(MemoryPrefs())
        val session = AuthSession(store, FakeAuthRepository())
        session.signIn(email = "a@b.com", password = "secret")
        assertTrue(session.isSignedIn)

        session.signOut()

        assertFalse(session.isSignedIn)
        assertNull(store.loadAccessToken())
        assertNull(session.userId.value)
    }

    @Test
    fun restoredUserId_parsesJwtSubject() {
        assertEquals(99, AuthSession.restoredUserId(fakeJwt(99)))
        assertNull(AuthSession.restoredUserId("not-a-jwt"))
        assertNull(AuthSession.restoredUserId(null))
    }

    companion object {
        fun fakeJwt(userId: Int): String {
            val header = Base64.getUrlEncoder().withoutPadding()
                .encodeToString("""{"alg":"none"}""".toByteArray())
            val payload = Base64.getUrlEncoder().withoutPadding()
                .encodeToString("""{"sub":"$userId"}""".toByteArray())
            return "$header.$payload.sig"
        }
    }
}

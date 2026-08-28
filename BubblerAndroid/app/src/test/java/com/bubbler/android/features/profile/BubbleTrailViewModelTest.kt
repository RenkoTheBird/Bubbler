package com.bubbler.android.features.profile

import android.content.SharedPreferences
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.GraphInteractionType
import com.bubbler.android.data.model.Interaction
import com.bubbler.android.data.repository.AuthRepository
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

class BubbleTrailViewModelTest {
    private lateinit var userRepository: FakeUserRepository
    private lateinit var authSession: AuthSession
    private lateinit var viewModel: BubbleTrailViewModel
    private val now: Instant = Instant.parse("2026-08-03T12:00:00Z")

    @Before
    fun setUp() {
        userRepository = FakeUserRepository()
        authSession = signedInSession(userId = 42)
        viewModel = BubbleTrailViewModel(
            authSession = authSession,
            userRepository = userRepository,
        )
    }

    @Test
    fun load_populatesInteractions() = runTest {
        userRepository.interactions = listOf(
            interaction(id = "1", type = GraphInteractionType.PREFERENCE, topic = "technology", feedPreference = 2),
            interaction(id = "2", type = GraphInteractionType.SKIP, topic = ""),
        )

        viewModel.loadAwait()

        assertEquals(2, viewModel.interactions.value.size)
        assertEquals("Much more for a Technology post", viewModel.interactions.value[0].trailSummary)
        assertEquals("Skipped a post", viewModel.interactions.value[1].trailSummary)
        assertNull(viewModel.errorMessage.value)
        assertFalse(viewModel.isLoading.value)
    }

    @Test
    fun load_skipsSecondCallUnlessForced() = runTest {
        userRepository.interactions = listOf(
            interaction(id = "1", type = GraphInteractionType.EXPLORE, topic = "sports"),
        )
        viewModel.loadAwait()
        userRepository.interactions = emptyList()

        viewModel.loadAwait(force = false)
        assertEquals(1, viewModel.interactions.value.size)

        viewModel.loadAwait(force = true)
        assertTrue(viewModel.interactions.value.isEmpty())
    }

    @Test
    fun load_unauthorized_signsOut() = runTest {
        userRepository.failWith = ApiException.Unauthorized

        viewModel.loadAwait()

        assertNull(authSession.accessToken.value)
        assertEquals("We couldn't load your bubble trail.", viewModel.errorMessage.value)
    }

    private fun interaction(
        id: String,
        type: GraphInteractionType,
        topic: String,
        feedPreference: Int? = null,
    ) = Interaction(
        id = id,
        userId = "42",
        postId = "post-$id",
        type = type,
        createdAt = now,
        topic = topic,
        viewTime = 1.0,
        feedPreference = feedPreference,
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
        var interactions: List<Interaction> = emptyList()
        var failWith: Exception? = null

        override suspend fun getMyInteractions(): List<Interaction> {
            failWith?.let { throw it }
            return interactions
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

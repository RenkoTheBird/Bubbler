package com.bubbler.android.features.settings.preferences

import android.content.SharedPreferences
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.CompositionWeights
import com.bubbler.android.data.model.FeedPreset
import com.bubbler.android.data.model.PreferencesUpdatePayload
import com.bubbler.android.data.model.UserPreferences
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.PreferencesRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Base64

class PreferencesViewModelTest {
    private lateinit var preferencesRepository: FakePreferencesRepository
    private lateinit var authSession: AuthSession
    private lateinit var viewModel: PreferencesViewModel

    @Before
    fun setUp() {
        preferencesRepository = FakePreferencesRepository()
        authSession = signedInSession(userId = 42)
        viewModel = PreferencesViewModel(
            authSession = authSession,
            preferencesRepository = preferencesRepository,
        )
    }

    @Test
    fun refreshFromServer_loadsPreferences() = runTest {
        preferencesRepository.stored = UserPreferences.systemDefaults(42).copy(
            feedPreset = FeedPreset.WILD_WALK,
            topicComposition = CompositionWeights(
                similar = 0.15,
                opposite = 0.25,
                surprise = 0.60,
            ),
        )

        viewModel.refreshFromServerAwait()

        assertEquals(FeedPreset.WILD_WALK, viewModel.preferences.value.feedPreset)
        assertEquals(0.60, viewModel.preferences.value.topicComposition.surprise, 0.0)
        assertFalse(viewModel.isLoading.value)
        assertNull(viewModel.errorMessage.value)
    }

    @Test
    fun savePreferences_sanitizesAndNormalizesComposition() = runTest {
        preferencesRepository.stored = UserPreferences.systemDefaults(42)
        viewModel.refreshFromServerAwait()

        viewModel.updateTopicComposition(similar = 2.0, opposite = 2.0, surprise = 0.0)
        preferencesRepository.stored = UserPreferences.systemDefaults(42).copy(
            feedPreset = FeedPreset.CUSTOM,
            topicComposition = CompositionWeights(
                similar = 0.5,
                opposite = 0.5,
                surprise = 0.0,
            ),
        )

        viewModel.savePreferencesAwait()

        val payload = preferencesRepository.lastUpdatePayload
            ?: error("expected update payload")
        assertEquals(FeedPreset.CUSTOM, payload.feedPreset)
        assertEquals(0.5, payload.topicComposition.similar, 1e-9)
        assertEquals(0.5, payload.topicComposition.opposite, 1e-9)
        assertEquals(
            "Your recommendation settings were saved successfully.",
            viewModel.successMessage.value,
        )
    }

    @Test
    fun selectPreset_updatesCompositions() = runTest {
        preferencesRepository.stored = UserPreferences.systemDefaults(42)
        viewModel.refreshFromServerAwait()

        viewModel.selectPreset(FeedPreset.CROSS_POLLINATE)

        assertEquals(FeedPreset.CROSS_POLLINATE, viewModel.preferences.value.feedPreset)
        assertEquals(0.55, viewModel.preferences.value.topicComposition.opposite, 0.0)
        assertEquals(0.55, viewModel.preferences.value.postComposition.similar, 0.0)
    }

    @Test
    fun restoreDefaults_resetsLocallyWithoutSaving() = runTest {
        preferencesRepository.stored = UserPreferences.systemDefaults(42).applyPreset(
            FeedPreset.WILD_WALK,
        )
        viewModel.refreshFromServerAwait()
        viewModel.restoreDefaults()

        assertEquals(FeedPreset.STAY_IN_LANE, viewModel.preferences.value.feedPreset)
        assertNull(preferencesRepository.lastUpdatePayload)
        assertTrue(viewModel.successMessage.value?.contains("Defaults restored") == true)
    }

    @Test
    fun savePreferences_forcesAiTopicDetectionOffWhenUnavailable() = runTest {
        preferencesRepository.stored = UserPreferences.systemDefaults(42).copy(
            aiTopicDetection = true,
        )
        viewModel.refreshFromServerAwait()
        assertFalse(viewModel.preferences.value.aiTopicDetection)

        preferencesRepository.stored = UserPreferences.systemDefaults(42)
        viewModel.savePreferencesAwait()

        assertFalse(preferencesRepository.lastUpdatePayload!!.aiTopicDetection)
    }

    @Test
    fun load_unauthorized_signsOut() = runTest {
        preferencesRepository.failWith = ApiException.Unauthorized

        viewModel.refreshFromServerAwait()

        assertNull(authSession.accessToken.value)
        assertEquals(
            "Your session has expired. Please log in again.",
            viewModel.errorMessage.value,
        )
    }

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

    private class FakePreferencesRepository : PreferencesRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        var stored: UserPreferences = UserPreferences.PLACEHOLDER
        var lastUpdatePayload: PreferencesUpdatePayload? = null
        var failWith: Exception? = null

        override suspend fun getPreferences(): UserPreferences {
            failWith?.let { throw it }
            return stored
        }

        override suspend fun updatePreferences(payload: PreferencesUpdatePayload): UserPreferences {
            failWith?.let { throw it }
            lastUpdatePayload = payload
            return stored
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

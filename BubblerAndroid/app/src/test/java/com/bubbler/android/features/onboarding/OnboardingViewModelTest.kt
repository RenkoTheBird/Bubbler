package com.bubbler.android.features.onboarding

import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.model.FeedPreset
import com.bubbler.android.data.model.PreferencesUpdatePayload
import com.bubbler.android.data.model.UserPreferences
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.PreferencesRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OnboardingViewModelTest {
    @Test
    fun completeOnboarding_marksServerAndSessionComplete() = runTest {
        val tokenStore = TokenStore(FakePrefs())
        tokenStore.saveAccessToken("token")
        val preferencesRepository = FakePreferencesRepository()
        val authSession = AuthSession(
            tokenStore = tokenStore,
            authRepository = AuthRepository(ApiClient(baseUrl = "http://localhost")),
            preferencesRepository = preferencesRepository,
        )
        val viewModel = OnboardingViewModel(preferencesRepository)

        viewModel.loadPreferences(authSession)
        viewModel.selectPreset(FeedPreset.CROSS_POLLINATE)

        var completed = false
        viewModel.completeOnboarding(authSession) { completed = true }

        assertTrue(completed)
        assertEquals(FeedPreset.CROSS_POLLINATE, viewModel.preferences.value.feedPreset)
        assertTrue(viewModel.preferences.value.onboardingCompleted)
        assertEquals(
            com.bubbler.android.core.auth.OnboardingGate.Complete,
            authSession.onboardingGate.value,
        )
    }

    private class FakePreferencesRepository : PreferencesRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(FakePrefs()),
    ) {
        var stored = UserPreferences.systemDefaults(userId = 5)

        override suspend fun getPreferences(): UserPreferences = stored

        override suspend fun updatePreferences(payload: PreferencesUpdatePayload): UserPreferences {
            stored = stored.copy(
                feedPreset = payload.feedPreset,
                topicComposition = payload.topicComposition,
                postComposition = payload.postComposition,
                topicPreferences = payload.topicPreferences,
                useViewTime = payload.useViewTime,
                viewTimeWeight = payload.viewTimeWeight,
                useRecency = payload.useRecency,
                aiTopicDetection = payload.aiTopicDetection,
                onboardingCompleted = payload.onboardingCompleted,
            ).sanitized()
            return stored
        }
    }

    private class FakePrefs : android.content.SharedPreferences {
        private val map = mutableMapOf<String, String?>()
        override fun getAll(): MutableMap<String, *> = map
        override fun getString(key: String?, defValue: String?): String? =
            map[key] ?: defValue
        override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? = defValues
        override fun getInt(key: String?, defValue: Int): Int = defValue
        override fun getLong(key: String?, defValue: Long): Long = defValue
        override fun getFloat(key: String?, defValue: Float): Float = defValue
        override fun getBoolean(key: String?, defValue: Boolean): Boolean = defValue
        override fun contains(key: String?): Boolean = map.containsKey(key)
        override fun edit(): android.content.SharedPreferences.Editor = object : android.content.SharedPreferences.Editor {
            override fun putString(key: String?, value: String?) = apply { map[key] = value }
            override fun putStringSet(key: String?, values: MutableSet<String>?) = this
            override fun putInt(key: String?, value: Int) = this
            override fun putLong(key: String?, value: Long) = this
            override fun putFloat(key: String?, value: Float) = this
            override fun putBoolean(key: String?, value: Boolean) = this
            override fun remove(key: String?) = apply { map.remove(key) }
            override fun clear() = apply { map.clear() }
            override fun commit(): Boolean = true
            override fun apply() {}
        }
        override fun registerOnSharedPreferenceChangeListener(
            listener: android.content.SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
        override fun unregisterOnSharedPreferenceChangeListener(
            listener: android.content.SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }
}

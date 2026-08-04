package com.bubbler.android.features.settings.blocks

import android.content.SharedPreferences
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.BlockedUser
import com.bubbler.android.data.model.User
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.BlocksRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant
import java.util.Base64

class BlocksViewModelTest {
    private lateinit var blocksRepository: FakeBlocksRepository
    private lateinit var authSession: AuthSession
    private lateinit var viewModel: BlocksViewModel
    private val now: Instant = Instant.parse("2026-08-03T12:00:00Z")

    @Before
    fun setUp() {
        blocksRepository = FakeBlocksRepository()
        authSession = signedInSession(userId = 42)
        viewModel = BlocksViewModel(
            authSession = authSession,
            blocksRepository = blocksRepository,
        )
    }

    @Test
    fun loadBlockedUsers_populatesList() = runTest {
        blocksRepository.blocked = listOf(
            blockedUser(id = 1, username = "alex"),
            blockedUser(id = 2, username = "sam"),
        )

        viewModel.loadBlockedUsersAwait()

        assertEquals(listOf("alex", "sam"), viewModel.blockedUsers.value.map { it.username })
        assertFalse(viewModel.isLoading.value)
        assertNull(viewModel.errorMessage.value)
    }

    @Test
    fun loadBlockedUsers_skipsSecondCallUnlessForced() = runTest {
        blocksRepository.blocked = listOf(blockedUser(id = 1, username = "alex"))
        viewModel.loadBlockedUsersAwait()

        blocksRepository.blocked = emptyList()
        viewModel.loadBlockedUsersAwait(force = false)
        assertEquals(1, viewModel.blockedUsers.value.size)

        viewModel.loadBlockedUsersAwait(force = true)
        assertTrue(viewModel.blockedUsers.value.isEmpty())
    }

    @Test
    fun unblock_removesUserFromList() = runTest {
        val alex = blockedUser(id = 1, username = "alex")
        val sam = blockedUser(id = 2, username = "sam")
        blocksRepository.blocked = listOf(alex, sam)
        viewModel.loadBlockedUsersAwait()

        viewModel.unblockAwait(alex)

        assertEquals(listOf("sam"), viewModel.blockedUsers.value.map { it.username })
        assertEquals(listOf("alex"), blocksRepository.unblocked)
        assertNull(viewModel.errorMessage.value)
    }

    @Test
    fun unblock_failure_setsError() = runTest {
        val alex = blockedUser(id = 1, username = "alex")
        blocksRepository.blocked = listOf(alex)
        viewModel.loadBlockedUsersAwait()
        blocksRepository.failUnblockWith = ApiException.ServerError(500, "boom")

        viewModel.unblockAwait(alex)

        assertEquals(listOf(alex), viewModel.blockedUsers.value)
        assertEquals("Couldn't unblock user", viewModel.errorTitle.value)
        assertEquals("boom", viewModel.errorMessage.value)
    }

    @Test
    fun load_unauthorized_signsOutWithoutErrorBanner() = runTest {
        blocksRepository.failWith = ApiException.Unauthorized

        viewModel.loadBlockedUsersAwait()

        assertNull(authSession.accessToken.value)
        assertNull(viewModel.errorMessage.value)
    }

    private fun blockedUser(id: Int, username: String) = BlockedUser(
        id = id,
        username = username,
        blockedAt = now,
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

    private class FakeBlocksRepository : BlocksRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        var blocked: List<BlockedUser> = emptyList()
        val unblocked = mutableListOf<String>()
        var failWith: Exception? = null
        var failUnblockWith: Exception? = null

        override suspend fun getBlockedUsers(): List<BlockedUser> {
            failWith?.let { throw it }
            return blocked
        }

        override suspend fun unblockUser(username: String): User {
            failUnblockWith?.let { throw it }
            unblocked += username
            return User(
                id = 0,
                username = username,
                createdAt = Instant.parse("2026-08-03T12:00:00Z"),
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

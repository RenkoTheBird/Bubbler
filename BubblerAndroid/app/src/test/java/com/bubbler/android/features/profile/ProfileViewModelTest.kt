package com.bubbler.android.features.profile

import android.content.SharedPreferences
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.BlockedUser
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.model.User
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.BlocksRepository
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

class ProfileViewModelTest {
    private lateinit var userRepository: FakeUserRepository
    private lateinit var blocksRepository: FakeBlocksRepository
    private lateinit var authSession: AuthSession
    private val now: Instant = Instant.parse("2026-08-03T12:00:00Z")

    @Before
    fun setUp() {
        userRepository = FakeUserRepository()
        blocksRepository = FakeBlocksRepository()
        authSession = signedInSession(userId = 42)
    }

    @Test
    fun uniqueTopics_preservesRecentOrder_andDedupesCaseInsensitive() {
        val posts = listOf(
            post("a", "Technology"),
            post("b", "sports"),
            post("c", "technology"),
            post("d", null),
            post("e", "  "),
            post("f", "Science"),
        )
        assertEquals(
            listOf("Technology", "sports", "Science"),
            ProfileViewModel.uniqueTopics(from = posts),
        )
    }

    @Test
    fun loadOwnProfile_setsUserAndPosts() = runTest {
        userRepository.myProfile = user(id = 42, username = "me")
        userRepository.myPosts = listOf(post("p1", "technology"), post("p2", "sports"))

        val viewModel = ownViewModel()
        viewModel.refreshPosts()

        assertEquals(42, viewModel.userId.value)
        assertEquals("me", viewModel.username.value)
        assertEquals(listOf("p1", "p2"), viewModel.posts.value.map { it.id })
        assertFalse(viewModel.isBlocked.value)
        assertNull(viewModel.errorMessage.value)
        assertFalse(viewModel.isLoading.value)
        assertEquals(
            "Active Bubble: Technology",
            viewModel.activeBubbleLabel(posts = viewModel.posts.value, isLoading = false),
        )
    }

    @Test
    fun loadPublicProfile_setsBlockedFlag() = runTest {
        userRepository.publicProfiles["alex"] = user(id = 7, username = "alex", isBlocked = true)
        userRepository.publicPosts["alex"] = listOf(post("x", "science"))

        val viewModel = publicViewModel("alex")
        viewModel.refreshPosts()

        assertEquals(7, viewModel.userId.value)
        assertEquals("alex", viewModel.username.value)
        assertTrue(viewModel.isBlocked.value)
        assertEquals(listOf("x"), viewModel.posts.value.map { it.id })
        assertTrue(viewModel.canManageBlock(sessionUserId = 42))
        assertEquals(
            "You blocked this user",
            viewModel.profileSubtitle(isBlocked = true),
        )
    }

    @Test
    fun softRefresh_keepsPostsVisibleWhileReloading() = runTest {
        userRepository.myProfile = user(id = 42, username = "me")
        userRepository.myPosts = listOf(post("p1", "technology"))

        val viewModel = ownViewModel()
        viewModel.refreshPosts()
        assertEquals(1, viewModel.posts.value.size)

        userRepository.myPosts = listOf(post("p1", "technology"), post("p2", "sports"))
        // Soft refresh: posts already present → isLoading stays false during call setup.
        // After await, both posts are present.
        viewModel.refreshPosts()
        assertEquals(listOf("p1", "p2"), viewModel.posts.value.map { it.id })
        assertFalse(viewModel.isLoading.value)
    }

    @Test
    fun blockUser_updatesIsBlocked() = runTest {
        userRepository.publicProfiles["alex"] = user(id = 7, username = "alex", isBlocked = false)
        userRepository.publicPosts["alex"] = emptyList()
        blocksRepository.blockResult = user(id = 7, username = "alex", isBlocked = true)

        val viewModel = publicViewModel("alex")
        viewModel.refreshPosts()
        viewModel.blockUserAwait()

        assertTrue(viewModel.isBlocked.value)
        assertEquals(listOf("alex"), blocksRepository.blocked)
        assertNull(viewModel.errorMessage.value)
    }

    @Test
    fun unblockUser_clearsIsBlocked() = runTest {
        userRepository.publicProfiles["alex"] = user(id = 7, username = "alex", isBlocked = true)
        userRepository.publicPosts["alex"] = emptyList()
        blocksRepository.unblockResult = user(id = 7, username = "alex", isBlocked = false)

        val viewModel = publicViewModel("alex")
        viewModel.refreshPosts()
        viewModel.unblockUserAwait()

        assertFalse(viewModel.isBlocked.value)
        assertEquals(listOf("alex"), blocksRepository.unblocked)
    }

    @Test
    fun load_unauthorized_signsOut() = runTest {
        userRepository.failWith = ApiException.Unauthorized

        val viewModel = ownViewModel()
        viewModel.refreshPosts()

        assertNull(authSession.accessToken.value)
        assertEquals("We couldn't load your profile.", viewModel.errorMessage.value)
    }

    @Test
    fun removePost_and_updatePostContent() = runTest {
        userRepository.myProfile = user(id = 42, username = "me")
        userRepository.myPosts = listOf(post("p1", "technology"), post("p2", "sports"))

        val viewModel = ownViewModel()
        viewModel.refreshPosts()
        viewModel.updatePostContent(id = "p1", content = "edited")
        assertEquals("edited", viewModel.posts.value.first { it.id == "p1" }.content)

        viewModel.removePost(id = "p2")
        assertEquals(listOf("p1"), viewModel.posts.value.map { it.id })
    }

    private fun ownViewModel() = ProfileViewModel(
        authSession = authSession,
        userRepository = userRepository,
        blocksRepository = blocksRepository,
        targetUsername = null,
    )

    private fun publicViewModel(username: String) = ProfileViewModel(
        authSession = authSession,
        userRepository = userRepository,
        blocksRepository = blocksRepository,
        targetUsername = username,
    )

    private fun post(id: String, topic: String?) = Post(
        id = id,
        userId = 1,
        username = "tester",
        content = "Post $id",
        createdAt = now,
        topic = topic,
    )

    private fun user(id: Int, username: String, isBlocked: Boolean = false) = User(
        id = id,
        username = username,
        email = if (isBlocked) null else "$username@example.com",
        createdAt = now,
        isBlocked = isBlocked,
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
        var myPosts: List<Post> = emptyList()
        val publicProfiles = mutableMapOf<String, User>()
        val publicPosts = mutableMapOf<String, List<Post>>()
        var failWith: Exception? = null

        override suspend fun getProfile(): User {
            failWith?.let { throw it }
            return myProfile ?: error("myProfile not set")
        }

        override suspend fun getMyPosts(): List<Post> {
            failWith?.let { throw it }
            return myPosts
        }

        override suspend fun getUser(username: String): User {
            failWith?.let { throw it }
            return publicProfiles[username] ?: error("missing public profile $username")
        }

        override suspend fun getUserPosts(username: String): List<Post> {
            failWith?.let { throw it }
            return publicPosts[username].orEmpty()
        }
    }

    private class FakeBlocksRepository : BlocksRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        var blockResult: User? = null
        var unblockResult: User? = null
        val blocked = mutableListOf<String>()
        val unblocked = mutableListOf<String>()

        override suspend fun getBlockedUsers(): List<BlockedUser> = emptyList()

        override suspend fun blockUser(username: String): User {
            blocked += username
            return blockResult ?: error("blockResult not set")
        }

        override suspend fun unblockUser(username: String): User {
            unblocked += username
            return unblockResult ?: error("unblockResult not set")
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

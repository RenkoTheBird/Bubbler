package com.bubbler.android.features.graph

import android.content.SharedPreferences
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.GraphInteractionPayload
import com.bubbler.android.data.model.GraphInteractionType
import com.bubbler.android.data.model.GraphSessionFeed
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.model.PreferenceType
import com.bubbler.android.data.model.PreferencesUpdatePayload
import com.bubbler.android.data.model.TopicPreference
import com.bubbler.android.data.model.UserPreferences
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.FeedRepository
import com.bubbler.android.data.repository.GraphRepository
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant
import java.util.ArrayDeque
import java.util.Base64

class GraphFeedViewModelTest {
    private lateinit var feedRepository: FakeFeedRepository
    private lateinit var graphRepository: FakeGraphRepository
    private lateinit var preferencesRepository: FakePreferencesRepository
    private lateinit var userRepository: FakeUserRepository
    private lateinit var postRepository: FakePostRepository
    private lateinit var authSession: AuthSession
    private lateinit var viewModel: GraphFeedViewModel

    private var now: Instant = Instant.parse("2026-08-03T12:00:00Z")

    @Before
    fun setUp() {
        feedRepository = FakeFeedRepository()
        graphRepository = FakeGraphRepository()
        preferencesRepository = FakePreferencesRepository()
        userRepository = FakeUserRepository()
        postRepository = FakePostRepository()
        authSession = AuthSession(
            tokenStore = TokenStore(MemoryPrefs()),
            authRepository = AuthRepository(ApiClient(baseUrl = "http://localhost")),
        )

        viewModel = GraphFeedViewModel(
            authSession = authSession,
            feedRepository = feedRepository,
            graphRepository = graphRepository,
            preferencesRepository = preferencesRepository,
            userRepository = userRepository,
            postRepository = postRepository,
            clock = { now },
        )
    }

    @Test
    fun load_setsCurrentAndQueuesRemainder() = runTest {
        feedRepository.enqueue(
            session(
                posts = listOf(post("a", "technology"), post("b", "sports"), post("c", "science")),
                seedStrategy = "soft_prior",
            ),
        )
        graphRepository.neighbors["a"] = listOf(post("n1", "technology"), post("n2", "sports"))

        viewModel.load()

        assertEquals("a", viewModel.currentNode.value?.id)
        assertEquals(listOf("n1", "n2"), viewModel.nextChoices.value.map { it.id })
        assertNull(viewModel.errorMessage.value)
        assertTrue(viewModel.statusMessage.value.orEmpty().isNotEmpty())
        assertFalse(viewModel.isLoading.value)
    }

    @Test
    fun load_retriesWithDiversify_afterEmptyOrBlacklistedSession() = runTest {
        preferencesRepository.preferences = preferencesRepository.preferences.copy(
            topicPreferences = listOf(
                TopicPreference("politics", PreferenceType.BLACKLISTED),
            ),
        )
        feedRepository.enqueue(
            session(posts = listOf(post("bad", "politics")), seedStrategy = "soft_prior"),
            session(posts = emptyList(), seedStrategy = "diversify"),
            session(
                posts = listOf(post("good", "technology"), post("queue", "sports")),
                seedStrategy = "diversify_fallback",
            ),
        )
        graphRepository.neighbors["good"] = emptyList()

        viewModel.load()

        assertEquals(listOf(false, true, true), feedRepository.diversifyFlags)
        assertEquals("good", viewModel.currentNode.value?.id)
        assertEquals("Exploring across topics", viewModel.seedStrategyLabel.value)
    }

    @Test
    fun skip_usesSessionQueue_whenNoNeighbors() = runTest {
        feedRepository.enqueue(
            session(
                posts = listOf(post("a", "technology"), post("b", "sports")),
                seedStrategy = "random",
            ),
        )
        graphRepository.neighbors["a"] = emptyList()
        graphRepository.neighbors["b"] = listOf(post("n1", "science"))

        viewModel.load()
        now = now.plusSeconds(5)
        viewModel.skipCurrentPost()

        assertEquals("b", viewModel.currentNode.value?.id)
        assertEquals(listOf("n1"), viewModel.nextChoices.value.map { it.id })
        assertEquals(1, userRepository.recorded.size)
        assertEquals(GraphInteractionType.SKIP, userRepository.recorded[0].type)
        assertEquals(5.0, userRepository.recorded[0].viewTime, 0.001)
    }

    @Test
    fun choose_recordsExploreAndAdvancesToSelection() = runTest {
        feedRepository.enqueue(
            session(posts = listOf(post("a", "technology")), seedStrategy = "random"),
        )
        val choice = post("choice", "sports")
        graphRepository.neighbors["a"] = listOf(choice)
        graphRepository.neighbors["choice"] = emptyList()

        viewModel.load()
        val selected = viewModel.nextChoices.value.first()
        now = now.plusSeconds(3)
        viewModel.choose(selected)

        assertEquals("choice", viewModel.currentNode.value?.id)
        assertEquals(GraphInteractionType.EXPLORE, userRepository.recorded.single().type)
        assertEquals(3.0, userRepository.recorded.single().viewTime, 0.001)
    }

    @Test
    fun syncTopicPreferences_blacklistedCurrent_startsDiversifiedSession() = runTest {
        feedRepository.enqueue(
            session(
                posts = listOf(post("a", "technology"), post("b", "sports")),
                seedStrategy = "soft_prior",
            ),
            session(posts = listOf(post("fresh", "science")), seedStrategy = "diversify"),
        )
        graphRepository.neighbors["a"] = listOf(post("n1", "technology"))
        graphRepository.neighbors["fresh"] = emptyList()

        viewModel.load()
        preferencesRepository.preferences = preferencesRepository.preferences.copy(
            topicPreferences = listOf(
                TopicPreference("technology", PreferenceType.BLACKLISTED),
            ),
        )

        viewModel.syncTopicPreferences()

        assertEquals("fresh", viewModel.currentNode.value?.id)
        assertEquals(GraphInteractionType.SKIP, userRepository.recorded.single().type)
        assertTrue(feedRepository.diversifyFlags.last())
    }

    @Test
    fun unauthorized_signsOut() = runTest {
        val tokenStore = TokenStore(MemoryPrefs()).apply {
            saveAccessToken(dummyJwt(userId = 7))
        }
        authSession = AuthSession(
            tokenStore = tokenStore,
            authRepository = AuthRepository(ApiClient(baseUrl = "http://localhost")),
        )
        assertTrue(authSession.isSignedIn)

        preferencesRepository.failWith = ApiException.Unauthorized
        viewModel = GraphFeedViewModel(
            authSession = authSession,
            feedRepository = feedRepository,
            graphRepository = graphRepository,
            preferencesRepository = preferencesRepository,
            userRepository = userRepository,
            postRepository = postRepository,
            clock = { now },
        )

        viewModel.load()

        assertFalse(authSession.isSignedIn)
        assertEquals(ApiException.Unauthorized.message, viewModel.errorMessage.value)
    }

    @Test
    fun load_failsAfterThreeUnusableSessions() = runTest {
        feedRepository.enqueue(
            session(posts = emptyList(), seedStrategy = "soft_prior"),
            session(posts = emptyList(), seedStrategy = "diversify"),
            session(posts = emptyList(), seedStrategy = "diversify_fallback"),
        )

        viewModel.load()

        assertEquals(listOf(false, true, true), feedRepository.diversifyFlags)
        assertNull(viewModel.currentNode.value)
        assertTrue(viewModel.nextChoices.value.isEmpty())
        assertEquals(
            "No session posts matched your current topic rules.",
            viewModel.errorMessage.value,
        )
    }

    @Test
    fun refreshSession_forcesDiversifyOnFirstAttempt() = runTest {
        feedRepository.enqueue(
            session(posts = listOf(post("fresh", "science")), seedStrategy = "diversify"),
        )
        graphRepository.neighbors["fresh"] = emptyList()

        viewModel.refreshSession()

        assertEquals(listOf(true), feedRepository.diversifyFlags)
        assertEquals("fresh", viewModel.currentNode.value?.id)
    }

    @Test
    fun skip_prefersNeighborOverSessionQueue() = runTest {
        feedRepository.enqueue(
            session(
                posts = listOf(post("a", "technology"), post("queued", "sports")),
                seedStrategy = "random",
            ),
        )
        graphRepository.neighbors["a"] = listOf(post("neighbor", "science"))
        graphRepository.neighbors["neighbor"] = emptyList()

        viewModel.load()
        viewModel.skipCurrentPost()

        assertEquals("neighbor", viewModel.currentNode.value?.id)
        assertEquals(GraphInteractionType.SKIP, userRepository.recorded.single().type)
    }

    @Test
    fun skip_withEmptyNeighborsAndQueue_startsDiversifiedSession() = runTest {
        feedRepository.enqueue(
            session(posts = listOf(post("a", "technology")), seedStrategy = "random"),
            session(posts = listOf(post("fresh", "entertainment")), seedStrategy = "diversify"),
        )
        graphRepository.neighbors["a"] = emptyList()
        graphRepository.neighbors["fresh"] = emptyList()

        viewModel.load()
        viewModel.skipCurrentPost()

        assertEquals("fresh", viewModel.currentNode.value?.id)
        assertTrue(feedRepository.diversifyFlags.last())
        assertEquals(
            listOf(GraphInteractionType.SKIP),
            userRepository.recorded.map { it.type },
        )
    }

    @Test
    fun loadChoices_filtersBlacklistedAndSelf() = runTest {
        preferencesRepository.preferences = preferencesRepository.preferences.copy(
            topicPreferences = listOf(
                TopicPreference("politics", PreferenceType.BLACKLISTED),
            ),
        )
        feedRepository.enqueue(
            session(posts = listOf(post("a", "technology")), seedStrategy = "random"),
        )
        graphRepository.neighbors["a"] = listOf(
            post("a", "technology"),
            post("bad", "politics"),
            post("good", "sports"),
        )

        viewModel.load()

        assertEquals(listOf("good"), viewModel.nextChoices.value.map { it.id })
        assertFalse(viewModel.nextChoices.value.any { it.isBlacklistedTopic })
    }

    @Test
    fun loadChoices_ranksPreferredTopicsFirst() = runTest {
        preferencesRepository.preferences = preferencesRepository.preferences.copy(
            topicPreferences = listOf(
                TopicPreference("sports", PreferenceType.PREFERRED),
            ),
        )
        feedRepository.enqueue(
            session(posts = listOf(post("a", "technology")), seedStrategy = "random"),
        )
        graphRepository.neighbors["a"] = listOf(
            post("n1", "science"),
            post("n2", "sports"),
            post("n3", "entertainment"),
        )

        viewModel.load()

        assertEquals(listOf("n2", "n1", "n3"), viewModel.nextChoices.value.map { it.id })
        assertTrue(viewModel.nextChoices.value.first().isPreferredTopic)
    }

    @Test
    fun syncTopicPreferences_refreshesPreferredFlagsOnChoices() = runTest {
        feedRepository.enqueue(
            session(posts = listOf(post("a", "technology")), seedStrategy = "random"),
        )
        graphRepository.neighbors["a"] = listOf(post("n1", "sports"))

        viewModel.load()
        assertFalse(viewModel.nextChoices.value.first().isPreferredTopic)

        preferencesRepository.preferences = preferencesRepository.preferences.copy(
            topicPreferences = listOf(
                TopicPreference("sports", PreferenceType.PREFERRED),
            ),
        )
        viewModel.syncTopicPreferences()

        assertTrue(viewModel.nextChoices.value.first().isPreferredTopic)
        assertEquals("a", viewModel.currentNode.value?.id)
    }

    @Test
    fun handleCurrentPostDeleted_advancesViaQueue() = runTest {
        feedRepository.enqueue(
            session(
                posts = listOf(post("a", "technology"), post("b", "sports")),
                seedStrategy = "random",
            ),
        )
        graphRepository.neighbors["a"] = emptyList()
        graphRepository.neighbors["b"] = listOf(post("n1", "science"))

        viewModel.load()
        viewModel.handleCurrentPostDeleted()

        assertEquals("b", viewModel.currentNode.value?.id)
        assertEquals("Deleted your post and moved ahead.", viewModel.statusMessage.value)
        assertTrue(userRepository.recorded.isEmpty())
    }

    @Test
    fun updateCurrentPostContent_mutatesCurrentNodeOnly() = runTest {
        feedRepository.enqueue(
            session(posts = listOf(post("a", "technology")), seedStrategy = "random"),
        )
        graphRepository.neighbors["a"] = emptyList()

        viewModel.load()
        viewModel.updateCurrentPostContent("Edited bubble body")

        assertEquals("Edited bubble body", viewModel.currentNode.value?.post?.content)
        assertEquals("a", viewModel.currentNode.value?.id)
    }

    private fun session(
        posts: List<Post>,
        seedStrategy: String,
    ): GraphSessionFeed = GraphSessionFeed(
        posts = posts,
        seedStrategy = seedStrategy,
        diversify = seedStrategy.startsWith("diversify"),
    )

    private fun post(id: String, topic: String): Post = Post(
        id = id,
        userId = 1,
        username = "u$id",
        content = "content $id",
        createdAt = Instant.parse("2026-01-01T00:00:00Z"),
        topic = topic,
    )

    private fun dummyJwt(userId: Int): String {
        val header = "eyJhbGciOiJub25lIn0"
        val payload = Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"sub":"$userId"}""".toByteArray())
        return "$header.$payload.sig"
    }

    private class FakeFeedRepository : FeedRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        private val sessions = ArrayDeque<GraphSessionFeed>()
        val diversifyFlags = mutableListOf<Boolean>()

        fun enqueue(vararg feeds: GraphSessionFeed) {
            sessions.addAll(feeds)
        }

        override suspend fun getSessionFeed(diversify: Boolean): GraphSessionFeed {
            diversifyFlags += diversify
            return sessions.poll()
                ?: error("No queued session feed for diversify=$diversify")
        }
    }

    private class FakeGraphRepository : GraphRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        val neighbors = mutableMapOf<String, List<Post>>()

        override suspend fun getNextGraphPosts(postId: String): List<Post> =
            neighbors[postId] ?: emptyList()
    }

    private class FakePreferencesRepository : PreferencesRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        var preferences: UserPreferences = UserPreferences.systemDefaults(userId = 1)
        var failWith: Exception? = null

        override suspend fun getPreferences(): UserPreferences {
            failWith?.let { throw it }
            return preferences
        }

        override suspend fun updatePreferences(payload: PreferencesUpdatePayload): UserPreferences {
            failWith?.let { throw it }
            preferences = preferences.copy(
                feedPreset = payload.feedPreset,
                topicComposition = payload.topicComposition,
                postComposition = payload.postComposition,
                topicPreferences = payload.topicPreferences,
                useViewTime = payload.useViewTime,
                viewTimeWeight = payload.viewTimeWeight,
                useRecency = payload.useRecency,
                aiTopicDetection = payload.aiTopicDetection,
            ).sanitized()
            return preferences
        }
    }

    private class FakeUserRepository : UserRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        val recorded = mutableListOf<GraphInteractionPayload>()

        override suspend fun recordInteraction(payload: GraphInteractionPayload) {
            recorded += payload
        }
    }

    private class FakePostRepository : PostRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    )

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

            override fun putStringSet(
                key: String?,
                values: MutableSet<String>?,
            ): SharedPreferences.Editor = this

            override fun putInt(key: String?, value: Int): SharedPreferences.Editor = this
            override fun putLong(key: String?, value: Long): SharedPreferences.Editor = this
            override fun putFloat(key: String?, value: Float): SharedPreferences.Editor = this
            override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor = this

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

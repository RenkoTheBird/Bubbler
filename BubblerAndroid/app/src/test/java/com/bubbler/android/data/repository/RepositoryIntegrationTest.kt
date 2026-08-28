package com.bubbler.android.data.repository

import android.content.SharedPreferences
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.data.model.FeedPreference
import com.bubbler.android.data.model.GraphInteractionPayload
import com.bubbler.android.data.model.GraphInteractionType
import com.bubbler.android.data.model.FeedPreset
import com.bubbler.android.data.model.PreferenceType
import com.bubbler.android.data.model.PreferencesUpdatePayload
import com.bubbler.android.data.model.TopicPreference
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class RepositoryIntegrationTest {
    private lateinit var server: MockWebServer
    private lateinit var apiClient: ApiClient
    private lateinit var tokenStore: TokenStore

    private lateinit var feedRepository: FeedRepository
    private lateinit var graphRepository: GraphRepository
    private lateinit var postRepository: PostRepository
    private lateinit var searchRepository: SearchRepository
    private lateinit var userRepository: UserRepository
    private lateinit var preferencesRepository: PreferencesRepository
    private lateinit var blocksRepository: BlocksRepository

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
        apiClient = ApiClient(baseUrl = server.url("/").toString().trimEnd('/'))
        tokenStore = TokenStore(MemoryPrefs())
        tokenStore.saveAccessToken("test-token")

        feedRepository = FeedRepository(apiClient, tokenStore)
        graphRepository = GraphRepository(apiClient, tokenStore)
        postRepository = PostRepository(apiClient, tokenStore)
        searchRepository = SearchRepository(apiClient, tokenStore)
        userRepository = UserRepository(apiClient, tokenStore)
        preferencesRepository = PreferencesRepository(apiClient, tokenStore)
        blocksRepository = BlocksRepository(apiClient, tokenStore)
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    @Test
    fun feed_getFeed_omitsEmptyQuery_andSendsBearer() = runTest {
        server.enqueue(samplePostListBody())

        val posts = feedRepository.getFeed()
        assertEquals(1, posts.size)
        assertEquals("p1", posts[0].id)

        val recorded = server.takeRequest()
        assertEquals("GET", recorded.method)
        assertEquals("/feed/me", recorded.path)
        assertEquals("Bearer test-token", recorded.getHeader("Authorization"))
    }

    @Test
    fun feed_getFeed_withQuery() = runTest {
        server.enqueue(MockResponse().setBody("[]"))
        feedRepository.getFeed(query = " space ")
        assertEquals("/feed/me?q=space", server.takeRequest().path)
    }

    @Test
    fun feed_getSessionFeed_diversify() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """{"posts":[],"seed_strategy":"diversify","diversify":true}""",
            ),
        )

        val session = feedRepository.getSessionFeed(diversify = true)
        assertEquals("diversify", session.seedStrategy)
        assertTrue(session.diversify)
        assertEquals("/feed/me/session?diversify=true", server.takeRequest().path)
    }

    @Test
    fun feed_getSessionFeed_defaultOmitsDiversifyParam() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """{"posts":[],"seed_strategy":"soft_prior","diversify":false}""",
            ),
        )
        feedRepository.getSessionFeed()
        assertEquals("/feed/me/session", server.takeRequest().path)
    }

    @Test
    fun graph_getNextGraphPosts() = runTest {
        server.enqueue(MockResponse().setBody("[]"))
        graphRepository.getNextGraphPosts("abc 1")
        assertEquals("/graph/posts/abc%201/next", server.takeRequest().path)
    }

    @Test
    fun post_createUpdateDeleteAndTopics() = runTest {
        server.enqueue(samplePostBody(id = "new", content = "hello", topic = "science"))
        val created = postRepository.createPost(content = "hello", topic = "science")
        assertEquals("new", created.id)
        val createReq = server.takeRequest()
        assertEquals("POST", createReq.method)
        assertEquals("/user/me/posts", createReq.path)
        assertTrue(createReq.body.readUtf8().contains("\"post\":\"hello\""))

        server.enqueue(samplePostBody(id = "new", content = "edited", topic = null))
        postRepository.updatePost(id = "new", content = "edited")
        val updateReq = server.takeRequest()
        assertEquals("PUT", updateReq.method)
        assertEquals("/user/me/posts/new", updateReq.path)

        server.enqueue(MockResponse().setResponseCode(204))
        postRepository.deletePost("new")
        val deleteReq = server.takeRequest()
        assertEquals("DELETE", deleteReq.method)
        assertEquals("/user/me/posts/new", deleteReq.path)

        server.enqueue(samplePostBody(id = "new", content = "hello", topic = "sports"))
        postRepository.addPostTopic("new", "sports")
        val addTopicReq = server.takeRequest()
        assertEquals("POST", addTopicReq.method)
        assertEquals("/user/me/posts/new/topics", addTopicReq.path)

        server.enqueue(samplePostBody(id = "new", content = "hello", topic = null))
        postRepository.removePostTopic("new", "sports")
        val removeTopicReq = server.takeRequest()
        assertEquals("DELETE", removeTopicReq.method)
        assertEquals("/user/me/posts/new/topics/sports", removeTopicReq.path)
    }

    @Test
    fun search_sendsQueryParam() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """{"query":"space","exact_matches":[],"related":[]}""",
            ),
        )
        val response = searchRepository.search(" space ")
        assertEquals("space", response.query)
        assertEquals("/search?q=space", server.takeRequest().path)
    }

    @Test
    fun user_profileFeedPreferencesInteractionsAndDelete() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """
                {
                  "id":7,"username":"wren","email":"wren@example.com",
                  "created_at":"2024-01-01T00:00:00Z"
                }
                """.trimIndent(),
            ),
        )
        assertEquals("wren", userRepository.getProfile().username)
        assertEquals("/user/me/profile", server.takeRequest().path)

        server.enqueue(
            MockResponse().setBody(
                """[{"post_id":"a","feed_preference":2},{"post_id":"b","feed_preference":-1}]""",
            ),
        )
        val prefs = userRepository.getFeedPreferences()
        assertEquals(2, prefs.size)
        assertEquals("/user/me/feed-preferences", server.takeRequest().path)

        server.enqueue(MockResponse().setBody("null"))
        userRepository.setFeedPreference("p1", FeedPreference.MORE)
        val preferenceReq = server.takeRequest()
        assertEquals("PUT", preferenceReq.method)
        assertEquals("/user/me/posts/p1/feed-preference", preferenceReq.path)
        assertTrue(preferenceReq.body.readUtf8().contains("\"feed_preference\":1"))

        server.enqueue(MockResponse().setBody("null"))
        userRepository.recordInteraction(
            GraphInteractionPayload("p1", GraphInteractionType.SKIP, 1.0),
        )
        val interactionReq = server.takeRequest()
        assertEquals("POST", interactionReq.method)
        assertEquals("/user/me/interactions", interactionReq.path)
        assertTrue(interactionReq.body.readUtf8().contains("\"type\":\"skip\""))

        server.enqueue(MockResponse().setResponseCode(204))
        userRepository.deleteAccount()
        val deleteReq = server.takeRequest()
        assertEquals("DELETE", deleteReq.method)
        assertEquals("/user/me", deleteReq.path)
    }

    @Test
    fun preferences_getAndUpdate() = runTest {
        server.enqueue(samplePreferencesBody())
        val prefs = preferencesRepository.getPreferences()
        assertEquals(1, prefs.userId)
        assertEquals("/user/me/preferences", server.takeRequest().path)

        server.enqueue(
            MockResponse().setBody(
                """
                {
                  "user_id": 1,
                  "feed_preset": "custom",
                  "topic_composition": {
                    "similar": 0.55,
                    "opposite": 0.15,
                    "surprise": 0.30
                  },
                  "post_composition": {
                    "similar": 0.55,
                    "opposite": 0.15,
                    "surprise": 0.30
                  },
                  "topic_preferences": [
                    {"topic":"science","preference_type":"preferred"}
                  ]
                }
                """.trimIndent(),
            ),
        )
        val updated = preferencesRepository.updatePreferences(
            PreferencesUpdatePayload(
                feedPreset = FeedPreset.CUSTOM,
                topicPreferences = listOf(
                    TopicPreference("science", PreferenceType.PREFERRED),
                ),
            ),
        )
        assertEquals(listOf("science"), updated.preferredTopics)
        assertEquals("PUT", server.takeRequest().method)
    }

    @Test
    fun blocks_listBlockUnblock() = runTest {
        server.enqueue(
            MockResponse().setBody(
                """[{"id":3,"username":"troll","blocked_at":"2024-08-01T00:00:00Z"}]""",
            ),
        )
        assertEquals("troll", blocksRepository.getBlockedUsers()[0].username)
        assertEquals("/user/me/blocks", server.takeRequest().path)

        server.enqueue(
            MockResponse().setBody(
                """
                {
                  "id": 3, "username": "troll",
                  "created_at": "2024-01-01T00:00:00Z",
                  "is_blocked": true
                }
                """.trimIndent(),
            ),
        )
        assertTrue(blocksRepository.blockUser("troll").isBlocked)
        assertEquals("POST", server.takeRequest().method)

        server.enqueue(
            MockResponse().setBody(
                """
                {
                  "id": 3, "username": "troll",
                  "created_at": "2024-01-01T00:00:00Z",
                  "is_blocked": false
                }
                """.trimIndent(),
            ),
        )
        assertFalse(blocksRepository.unblockUser("troll").isBlocked)
        assertEquals("DELETE", server.takeRequest().method)
    }

    @Test
    fun missingToken_throwsUnauthorized() = runTest {
        tokenStore.deleteAccessToken()
        try {
            feedRepository.getFeed()
            throw AssertionError("expected Unauthorized")
        } catch (_: ApiException.Unauthorized) {
            // expected
        }
    }

    @Test
    fun endpoints_withQuery_andPathEncoding() {
        assertEquals("feed/me", Endpoints.withQuery(Endpoints.FEED_ME, "q" to null))
        assertEquals("search?q=", Endpoints.withQuery(Endpoints.SEARCH, "q" to ""))
        assertEquals("user/a%20b/profile", Endpoints.userProfile("a b"))
    }

    private fun samplePostListBody(): MockResponse =
        MockResponse().setBody(
            """
            [{
              "id":"p1","user_id":1,"content":"hi",
              "created_at":"2024-01-01T00:00:00Z","topic":"general"
            }]
            """.trimIndent(),
        )

    private fun samplePostBody(id: String, content: String, topic: String?): MockResponse {
        val topicJson = if (topic == null) "null" else "\"$topic\""
        return MockResponse().setBody(
            """
            {
              "id":"$id","user_id":1,"content":"$content",
              "created_at":"2024-01-01T00:00:00Z","topic":$topicJson
            }
            """.trimIndent(),
        )
    }

    private fun samplePreferencesBody(): MockResponse =
        MockResponse().setBody(
            """
            {
              "user_id": 1,
              "feed_preset": "stay_in_lane",
              "topic_composition": {
                "similar": 0.55,
                "opposite": 0.15,
                "surprise": 0.30
              },
              "post_composition": {
                "similar": 0.55,
                "opposite": 0.15,
                "surprise": 0.30
              },
              "topic_preferences": []
            }
            """.trimIndent(),
        )

    private class MemoryPrefs : SharedPreferences {
        private val map = mutableMapOf<String, String?>()

        override fun getString(key: String?, defValue: String?): String? =
            if (map.containsKey(key)) map[key] else defValue

        override fun edit(): SharedPreferences.Editor = MemoryEditor()

        private inner class MemoryEditor : SharedPreferences.Editor {
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
}

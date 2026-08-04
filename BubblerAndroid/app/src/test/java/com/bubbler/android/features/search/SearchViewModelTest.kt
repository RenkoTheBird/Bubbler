package com.bubbler.android.features.search

import android.content.SharedPreferences
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.model.SearchResponse
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.SearchRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant
import java.util.Base64

class SearchViewModelTest {
    private lateinit var prefs: MemoryPrefs
    private lateinit var searchRepository: FakeSearchRepository
    private lateinit var authSession: AuthSession
    private lateinit var viewModel: SearchViewModel

    private val now: Instant = Instant.parse("2026-08-03T12:00:00Z")

    @Before
    fun setUp() {
        prefs = MemoryPrefs()
        searchRepository = FakeSearchRepository()
        authSession = signedInSession(userId = 42)
        viewModel = SearchViewModel(
            authSession = authSession,
            searchRepository = searchRepository,
            prefs = prefs,
        )
    }

    @Test
    fun prioritizeTopicMatches_whenKnownTopic_movesMatchesFirst() {
        val posts = listOf(
            post("a", "sports"),
            post("b", "technology"),
            post("c", "science"),
            post("d", "Technology"),
        )

        val ranked = SearchViewModel.prioritizeTopicMatches(posts, query = "technology")

        assertEquals(listOf("b", "d", "a", "c"), ranked.map { it.id })
    }

    @Test
    fun prioritizeTopicMatches_whenUnknownQuery_preservesOrder() {
        val posts = listOf(post("a", "sports"), post("b", "technology"))
        assertEquals(posts, SearchViewModel.prioritizeTopicMatches(posts, query = "bubbles"))
    }

    @Test
    fun matchesTopic_isCaseInsensitive_andIgnoresBlank() {
        assertTrue(SearchViewModel.matchesTopic(post("a", "Technology"), "technology"))
        assertFalse(SearchViewModel.matchesTopic(post("b", null), "technology"))
        assertFalse(SearchViewModel.matchesTopic(post("c", "  "), "technology"))
    }

    @Test
    fun record_dedupesCaseInsensitive_andCapsAtFive() {
        SearchViewModel.record(prefs, "Alpha", userId = 7)
        SearchViewModel.record(prefs, "beta", userId = 7)
        SearchViewModel.record(prefs, "gamma", userId = 7)
        SearchViewModel.record(prefs, "delta", userId = 7)
        SearchViewModel.record(prefs, "epsilon", userId = 7)
        val capped = SearchViewModel.record(prefs, "zeta", userId = 7)
        assertEquals(listOf("zeta", "epsilon", "delta", "gamma", "beta"), capped)

        val afterDupe = SearchViewModel.record(prefs, "GAMMA", userId = 7)
        assertEquals(listOf("GAMMA", "zeta", "epsilon", "delta", "beta"), afterDupe)
    }

    @Test
    fun loadRecentSearches_loadsPerUser() {
        SearchViewModel.record(prefs, "one", userId = 1)
        SearchViewModel.record(prefs, "two", userId = 2)

        viewModel.loadRecentSearches(1)
        assertEquals(listOf("one"), viewModel.recentSearches.value)

        viewModel.loadRecentSearches(2)
        assertEquals(listOf("two"), viewModel.recentSearches.value)
    }

    @Test
    fun search_populatesExactAndRelated_andRecordsRecent() = runTest {
        searchRepository.response = SearchResponse(
            query = "technology",
            exactMatches = listOf(post("e1", "sports"), post("e2", "technology")),
            related = listOf(post("r1", "science")),
        )

        viewModel.search(query = "technology", recordRecent = true)

        assertEquals(listOf("e2", "e1"), viewModel.exactMatches.value.map { it.id })
        assertEquals(listOf("r1"), viewModel.related.value.map { it.id })
        assertTrue(viewModel.hasSearched.value)
        assertEquals("technology", viewModel.lastQuery.value)
        assertEquals(listOf("technology"), viewModel.recentSearches.value)
        assertNull(viewModel.errorMessage.value)
        assertFalse(viewModel.isLoading.value)
    }

    @Test
    fun search_liveSearch_doesNotRecordRecent() = runTest {
        searchRepository.response = SearchResponse(
            query = "tech",
            exactMatches = listOf(post("e1", "technology")),
            related = emptyList(),
        )

        viewModel.search(query = "tech", recordRecent = false)

        assertTrue(viewModel.hasSearched.value)
        assertTrue(viewModel.recentSearches.value.isEmpty())
    }

    @Test
    fun search_emptyQuery_setsError() = runTest {
        viewModel.search(query = "   ", recordRecent = true)
        assertEquals("Enter a search to find bubbles.", viewModel.errorMessage.value)
        assertTrue(searchRepository.queries.isEmpty())
    }

    @Test
    fun search_unauthorized_signsOut() = runTest {
        searchRepository.error = ApiException.Unauthorized

        viewModel.search(query = "hello", recordRecent = true)

        assertEquals(ApiException.Unauthorized.message, viewModel.errorMessage.value)
        assertNull(authSession.accessToken.value)
        assertTrue(viewModel.exactMatches.value.isEmpty())
    }

    @Test
    fun removePost_and_updatePostContent_affectBothLists() = runTest {
        searchRepository.response = SearchResponse(
            query = "x",
            exactMatches = listOf(post("e1", "sports")),
            related = listOf(post("r1", "science")),
        )
        viewModel.search(query = "x", recordRecent = false)

        viewModel.updatePostContent(id = "e1", content = "edited exact")
        viewModel.updatePostContent(id = "r1", content = "edited related")
        assertEquals("edited exact", viewModel.exactMatches.value.single().content)
        assertEquals("edited related", viewModel.related.value.single().content)

        viewModel.removePost(id = "e1")
        viewModel.removePost(id = "r1")
        assertTrue(viewModel.exactMatches.value.isEmpty())
        assertTrue(viewModel.related.value.isEmpty())
    }

    @Test
    fun clearSearch_resetsTextAndResults() = runTest {
        searchRepository.response = SearchResponse(
            query = "tech",
            exactMatches = listOf(post("e1", "technology")),
            related = emptyList(),
        )
        viewModel.search(query = "tech", recordRecent = false)

        viewModel.clearSearch()

        assertEquals("", viewModel.searchText.value)
        assertFalse(viewModel.hasSearched.value)
        assertTrue(viewModel.exactMatches.value.isEmpty())
        assertNull(viewModel.errorMessage.value)
    }

    private fun post(id: String, topic: String?): Post =
        Post(
            id = id,
            userId = 1,
            username = "tester",
            content = "Post $id",
            createdAt = now,
            topic = topic,
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

    private class FakeSearchRepository : SearchRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        var response: SearchResponse = SearchResponse(
            query = "",
            exactMatches = emptyList(),
            related = emptyList(),
        )
        var error: Exception? = null
        val queries = mutableListOf<String>()

        override suspend fun search(query: String): SearchResponse {
            queries += query
            error?.let { throw it }
            return response
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

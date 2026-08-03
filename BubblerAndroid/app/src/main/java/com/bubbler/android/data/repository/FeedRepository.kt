package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.data.model.GraphSessionFeed
import com.bubbler.android.data.model.Post

/** Ranked feed + graph session seed (`getFeed`, `getSessionFeed`). */
open class FeedRepository(
    private val apiClient: ApiClient,
    private val tokenStore: TokenStore,
) {
    /** Ranked feed. Optional [query] maps to `q` and seeds similar/opposite candidates. */
    open suspend fun getFeed(query: String? = null): List<Post> {
        val trimmed = query?.trim().orEmpty()
        val path = Endpoints.withQuery(
            Endpoints.FEED_ME,
            "q" to trimmed.ifEmpty { null },
        )
        return apiClient.get(path, token = tokenStore.requireAccessToken())
    }

    open suspend fun getSessionFeed(diversify: Boolean = false): GraphSessionFeed {
        val path = Endpoints.withQuery(
            Endpoints.FEED_ME_SESSION,
            "diversify" to if (diversify) "true" else null,
        )
        return apiClient.get(path, token = tokenStore.requireAccessToken())
    }
}

package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.data.model.Post

/** Graph neighbor fetch (`GET /graph/posts/{id}/next`). */
open class GraphRepository(
    private val apiClient: ApiClient,
    private val tokenStore: TokenStore,
) {
    open suspend fun getNextGraphPosts(postId: String): List<Post> =
        apiClient.get(
            Endpoints.graphNextPosts(postId),
            token = tokenStore.requireAccessToken(),
        )
}

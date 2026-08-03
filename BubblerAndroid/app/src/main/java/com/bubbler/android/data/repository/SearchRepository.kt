package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.data.model.SearchResponse

/** Hybrid search (`GET /search?q=...`). */
open class SearchRepository(
    private val apiClient: ApiClient,
    private val tokenStore: TokenStore,
) {
    open suspend fun search(query: String): SearchResponse {
        val trimmed = query.trim()
        val path = Endpoints.withQuery(Endpoints.SEARCH, "q" to trimmed)
        return apiClient.get(path, token = tokenStore.requireAccessToken())
    }
}

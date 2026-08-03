package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Hybrid search payload from `GET /search?q=...`. */
@Serializable
data class SearchResponse(
    val query: String,
    @SerialName("exact_matches")
    val exactMatches: List<Post> = emptyList(),
    val related: List<Post> = emptyList(),
) {
    val isEmpty: Boolean
        get() = exactMatches.isEmpty() && related.isEmpty()
}

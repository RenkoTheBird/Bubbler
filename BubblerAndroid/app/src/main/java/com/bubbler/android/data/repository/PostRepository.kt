package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.data.model.Post
import kotlinx.serialization.Serializable
import okhttp3.RequestBody.Companion.toRequestBody

/** Create / update / delete posts and topic mutations. */
open class PostRepository(
    private val apiClient: ApiClient,
    private val tokenStore: TokenStore,
) {
    open suspend fun createPost(content: String, topic: String): Post {
        val payload = apiClient.json.encodeToString(
            CreatePostBody.serializer(),
            CreatePostBody(post = content, topic = topic),
        )
        return apiClient.request(
            path = Endpoints.USER_ME_POSTS,
            method = "POST",
            token = tokenStore.requireAccessToken(),
            body = payload.toRequestBody(ApiClient.JSON_MEDIA_TYPE),
            contentType = "application/json",
        )
    }

    open suspend fun updatePost(id: String, content: String) {
        val payload = apiClient.json.encodeToString(
            UpdatePostBody.serializer(),
            UpdatePostBody(post = content),
        )
        apiClient.executeIgnoringBody(
            path = Endpoints.userPost(id),
            method = "PUT",
            token = tokenStore.requireAccessToken(),
            body = payload.toRequestBody(ApiClient.JSON_MEDIA_TYPE),
            contentType = "application/json",
        )
    }

    open suspend fun deletePost(id: String) {
        apiClient.executeIgnoringBody(
            path = Endpoints.userPost(id),
            method = "DELETE",
            token = tokenStore.requireAccessToken(),
        )
    }

    open suspend fun addPostTopic(postId: String, topic: String): Post {
        val payload = apiClient.json.encodeToString(
            PostTopicMutationBody.serializer(),
            PostTopicMutationBody(topic = topic),
        )
        return apiClient.request(
            path = Endpoints.userPostTopics(postId),
            method = "POST",
            token = tokenStore.requireAccessToken(),
            body = payload.toRequestBody(ApiClient.JSON_MEDIA_TYPE),
            contentType = "application/json",
        )
    }

    open suspend fun removePostTopic(postId: String, topic: String): Post =
        apiClient.request(
            path = Endpoints.userPostTopic(postId, topic),
            method = "DELETE",
            token = tokenStore.requireAccessToken(),
        )
}

@Serializable
private data class CreatePostBody(
    val post: String,
    val topic: String,
)

@Serializable
private data class UpdatePostBody(
    val post: String,
)

@Serializable
private data class PostTopicMutationBody(
    val topic: String,
)

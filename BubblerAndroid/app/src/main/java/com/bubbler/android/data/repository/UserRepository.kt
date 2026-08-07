package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.core.storage.DataExportWriter
import com.bubbler.android.data.model.GraphInteractionPayload
import com.bubbler.android.data.model.Interaction
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.model.User
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * Profile, posts, interactions, likes, account mutations.
 * (Email / password / delete account from iOS APIClient user routes.)
 */
open class UserRepository(
    private val apiClient: ApiClient,
    private val tokenStore: TokenStore,
) {
    open suspend fun getProfile(): User =
        apiClient.get(Endpoints.USER_ME_PROFILE, token = tokenStore.requireAccessToken())

    open suspend fun getUser(username: String): User =
        apiClient.get(Endpoints.userProfile(username), token = tokenStore.requireAccessToken())

    open suspend fun updateEmail(email: String): User {
        val payload = apiClient.json.encodeToString(
            EmailUpdateBody.serializer(),
            EmailUpdateBody(email = email),
        )
        return apiClient.request(
            path = Endpoints.USER_ME_PROFILE_EMAIL,
            method = "PUT",
            token = tokenStore.requireAccessToken(),
            body = payload.toRequestBody(ApiClient.JSON_MEDIA_TYPE),
            contentType = "application/json",
        )
    }

    open suspend fun updatePassword(
        emailOrUsername: String,
        currentPassword: String,
        newPassword: String,
        confirmNewPassword: String,
    ) {
        val payload = apiClient.json.encodeToString(
            PasswordUpdateBody.serializer(),
            PasswordUpdateBody(
                emailOrUsername = emailOrUsername,
                currentPassword = currentPassword,
                newPassword = newPassword,
                confirmNewPassword = confirmNewPassword,
            ),
        )
        apiClient.executeIgnoringBody(
            path = Endpoints.USER_ME_PROFILE_PASSWORD,
            method = "PUT",
            token = tokenStore.requireAccessToken(),
            body = payload.toRequestBody(ApiClient.JSON_MEDIA_TYPE),
            contentType = "application/json",
        )
    }

    open suspend fun getMyPosts(): List<Post> =
        apiClient.get(Endpoints.USER_ME_POSTS, token = tokenStore.requireAccessToken())

    open suspend fun getUserPosts(username: String): List<Post> =
        apiClient.get(Endpoints.userPosts(username), token = tokenStore.requireAccessToken())

    /** Recent interactions for the profile Bubble Trail (server caps at 20). */
    open suspend fun getMyInteractions(): List<Interaction> =
        apiClient.get(Endpoints.USER_ME, token = tokenStore.requireAccessToken())

    /** All post IDs the current user has liked (uncapped). */
    open suspend fun getLikedPostIds(): List<String> =
        apiClient.get(Endpoints.USER_ME_LIKES, token = tokenStore.requireAccessToken())

    open suspend fun recordInteraction(payload: GraphInteractionPayload) {
        val body = apiClient.json.encodeToString(
            GraphInteractionPayload.serializer(),
            payload,
        )
        apiClient.executeIgnoringBody(
            path = Endpoints.USER_ME_INTERACTIONS,
            method = "POST",
            token = tokenStore.requireAccessToken(),
            body = body.toRequestBody(ApiClient.JSON_MEDIA_TYPE),
            contentType = "application/json",
        )
    }

    open suspend fun deleteLike(postId: String) {
        apiClient.executeIgnoringBody(
            path = Endpoints.userInteractionLike(postId),
            method = "DELETE",
            token = tokenStore.requireAccessToken(),
        )
    }

    open suspend fun deleteAccount() {
        apiClient.executeIgnoringBody(
            path = Endpoints.USER_ME,
            method = "DELETE",
            token = tokenStore.requireAccessToken(),
        )
    }

    /**
     * Fetches the account export as pretty-printed JSON bytes ready for SAF save.
     */
    open suspend fun exportUserData(): ByteArray {
        val raw = apiClient.execute(
            path = Endpoints.USER_ME_EXPORT,
            method = "GET",
            token = tokenStore.requireAccessToken(),
        )
        return DataExportWriter.prettyPrintJson(raw)
    }
}

@Serializable
private data class EmailUpdateBody(
    val email: String,
)

@Serializable
private data class PasswordUpdateBody(
    @SerialName("email_or_username")
    val emailOrUsername: String,
    @SerialName("current_password")
    val currentPassword: String,
    @SerialName("new_password")
    val newPassword: String,
    @SerialName("confirm_new_password")
    val confirmNewPassword: String,
)

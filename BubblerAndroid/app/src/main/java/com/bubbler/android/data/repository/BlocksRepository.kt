package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.data.model.BlockedUser
import com.bubbler.android.data.model.User
import okhttp3.RequestBody.Companion.toRequestBody

/** List / block / unblock users. */
open class BlocksRepository(
    private val apiClient: ApiClient,
    private val tokenStore: TokenStore,
) {
    open suspend fun getBlockedUsers(): List<BlockedUser> =
        apiClient.get(Endpoints.USER_ME_BLOCKS, token = tokenStore.requireAccessToken())

    open suspend fun blockUser(username: String): User =
        apiClient.request(
            path = Endpoints.userBlock(username),
            method = "POST",
            token = tokenStore.requireAccessToken(),
            // OkHttp requires a body for POST even when the route takes none.
            body = ByteArray(0).toRequestBody(null),
        )

    open suspend fun unblockUser(username: String): User =
        apiClient.request(
            path = Endpoints.userBlock(username),
            method = "DELETE",
            token = tokenStore.requireAccessToken(),
        )
}

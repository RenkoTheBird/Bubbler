package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.data.model.PreferencesUpdatePayload
import com.bubbler.android.data.model.UserPreferences
import okhttp3.RequestBody.Companion.toRequestBody

/** Get / update recommendation preferences. */
open class PreferencesRepository(
    private val apiClient: ApiClient,
    private val tokenStore: TokenStore,
) {
    open suspend fun getPreferences(): UserPreferences =
        apiClient.get(Endpoints.USER_ME_PREFERENCES, token = tokenStore.requireAccessToken())

    open suspend fun updatePreferences(payload: PreferencesUpdatePayload): UserPreferences {
        val body = apiClient.json.encodeToString(
            PreferencesUpdatePayload.serializer(),
            payload,
        )
        return apiClient.request(
            path = Endpoints.USER_ME_PREFERENCES,
            method = "PUT",
            token = tokenStore.requireAccessToken(),
            body = body.toRequestBody(ApiClient.JSON_MEDIA_TYPE),
            contentType = "application/json",
        )
    }
}

package com.bubbler.android.data.repository

import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import okhttp3.FormBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.LocalDate

@Serializable
data class AuthResponse(
    @SerialName("access_token")
    val accessToken: String,
    @SerialName("token_type")
    val tokenType: String,
    @SerialName("user_id")
    val userId: Int,
)

/**
 * Auth domain HTTP calls (login / register from iOS APIClient).
 */
open class AuthRepository(
    private val apiClient: ApiClient,
) {
    /**
     * OAuth2 password form: field `username` carries the email address.
     */
    open suspend fun login(email: String, password: String): AuthResponse {
        val body = FormBody.Builder()
            .add("username", email)
            .add("password", password)
            .build()

        return apiClient.request(
            path = Endpoints.AUTH_LOGIN,
            method = "POST",
            body = body,
        )
    }

    /**
     * @param dateOfBirth calendar day only — sent as `YYYY-MM-DD`, never a UTC instant.
     */
    open suspend fun register(
        username: String,
        email: String,
        password: String,
        dateOfBirth: LocalDate,
    ): AuthResponse {
        val payload = apiClient.json.encodeToString(
            RegisterBody.serializer(),
            RegisterBody(
                username = username,
                email = email,
                password = password,
                dateOfBirth = dateOfBirth.toString(),
            ),
        )
        val body = payload.toRequestBody(ApiClient.JSON_MEDIA_TYPE)

        return apiClient.request(
            path = Endpoints.AUTH_REGISTER,
            method = "POST",
            body = body,
            contentType = "application/json",
        )
    }
}

@Serializable
private data class RegisterBody(
    val username: String,
    val email: String,
    val password: String,
    @SerialName("date_of_birth")
    val dateOfBirth: String,
)

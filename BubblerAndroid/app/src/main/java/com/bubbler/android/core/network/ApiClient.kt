package com.bubbler.android.core.network

import com.bubbler.android.core.config.ApiConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

@Serializable
data class BackendHealth(
    val status: String,
    val database: String,
)

/**
 * Thin HTTP transport. Domain calls live in repositories (Phase 1+).
 * Health is here so Phase 0 can prove connectivity without a separate client.
 */
class ApiClient(
    private val baseUrl: String = ApiConfig.BASE_URL,
    private val client: OkHttpClient = defaultClient(),
    @PublishedApi internal val json: Json = defaultJson(),
) {
    suspend fun health(): BackendHealth = get(Endpoints.HEALTH)

    suspend inline fun <reified T> get(
        path: String,
        token: String? = null,
    ): T = request(path = path, method = "GET", token = token)

    suspend inline fun <reified T> request(
        path: String,
        method: String,
        token: String? = null,
        body: RequestBody? = null,
        contentType: String? = null,
    ): T {
        val raw = execute(
            path = path,
            method = method,
            token = token,
            body = body,
            contentType = contentType,
        )
        return try {
            json.decodeFromString<T>(raw)
        } catch (_: Exception) {
            throw ApiException.InvalidResponse
        }
    }

    suspend fun execute(
        path: String,
        method: String,
        token: String? = null,
        body: RequestBody? = null,
        contentType: String? = null,
    ): String = withContext(Dispatchers.IO) {
        val url = joinUrl(baseUrl, path)
        val builder = Request.Builder().url(url).method(method, body)
        if (token != null) {
            builder.header("Authorization", "Bearer $token")
        }
        if (contentType != null) {
            builder.header("Content-Type", contentType)
        }

        val response = try {
            client.newCall(builder.build()).execute()
        } catch (e: IOException) {
            throw ApiException.Network("Could not reach the server.", e)
        }

        response.use { resp ->
            val bytes = resp.body?.bytes() ?: ByteArray(0)
            when {
                resp.code == 401 -> throw ApiException.Unauthorized
                !resp.isSuccessful -> {
                    val message = parseErrorMessage(bytes) ?: "Request failed (${resp.code})."
                    throw ApiException.ServerError(resp.code, message)
                }
                // 204 / empty success bodies are valid (delete like, delete post, delete account).
                bytes.isEmpty() -> ""
                else -> bytes.decodeToString()
            }
        }
    }

    /** Authenticated call that discards the body (204 or ignored JSON). */
    suspend fun executeIgnoringBody(
        path: String,
        method: String,
        token: String,
        body: RequestBody? = null,
        contentType: String? = null,
    ) {
        execute(
            path = path,
            method = method,
            token = token,
            body = body,
            contentType = contentType,
        )
    }

    fun parseErrorMessage(bytes: ByteArray): String? {
        if (bytes.isEmpty()) return null
        return try {
            json.decodeFromString<ApiErrorBody>(bytes.decodeToString()).detail
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

        fun defaultClient(): OkHttpClient =
            OkHttpClient.Builder()
                .connectTimeout(ApiConfig.CONNECT_TIMEOUT_MS, TimeUnit.MILLISECONDS)
                .readTimeout(ApiConfig.READ_TIMEOUT_MS, TimeUnit.MILLISECONDS)
                .build()

        fun defaultJson(): Json =
            Json {
                ignoreUnknownKeys = true
                isLenient = true
            }

        fun joinUrl(baseUrl: String, path: String): String {
            val base = baseUrl.trimEnd('/')
            val suffix = path.trimStart('/')
            return "$base/$suffix"
        }
    }
}

@Serializable
private data class ApiErrorBody(
    val detail: String,
)

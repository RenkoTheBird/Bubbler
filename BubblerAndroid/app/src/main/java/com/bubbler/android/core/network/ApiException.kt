package com.bubbler.android.core.network

sealed class ApiException(message: String) : Exception(message) {
    data object InvalidResponse : ApiException("Unexpected response from the server.")

    data object Unauthorized : ApiException("Your session has expired. Please log in again.")

    data class ServerError(
        val statusCode: Int,
        override val message: String,
    ) : ApiException(message)

    data class Network(
        override val message: String,
        override val cause: Throwable? = null,
    ) : ApiException(message)
}

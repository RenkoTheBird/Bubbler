package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

@Serializable
data class Post(
    val id: String,
    @SerialName("user_id")
    val userId: Int,
    val username: String? = null,
    val content: String,
    @SerialName("created_at")
    @Serializable(with = InstantIsoSerializer::class)
    val createdAt: Instant,
    val topic: String? = null,
    val embedding: List<Double>? = null,
) {
    val authorLabel: String
        get() {
            val name = username?.trim().orEmpty()
            return if (name.isNotEmpty()) "@$name" else "user #$userId"
        }
}

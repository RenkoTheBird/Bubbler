package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/**
 * Consolidated user profile.
 *
 * - Own profile (`GET /user/me/profile`): [email] present, [isBlocked] absent/false.
 * - Public profile (`GET /user/{username}/profile`): no email, optional [isBlocked].
 */
@Serializable
data class User(
    val id: Int,
    val username: String,
    val email: String? = null,
    @SerialName("created_at")
    @Serializable(with = InstantIsoSerializer::class)
    val createdAt: Instant,
    @SerialName("is_blocked")
    val isBlocked: Boolean = false,
)

package com.bubbler.android.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/** A user the current account has blocked (`GET /user/me/blocks`). */
@Serializable
data class BlockedUser(
    val id: Int,
    val username: String,
    @SerialName("blocked_at")
    @Serializable(with = InstantIsoSerializer::class)
    val blockedAt: Instant,
)

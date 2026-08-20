package com.bubbler.android.core.network

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

object Endpoints {
    const val HEALTH = "health"
    const val AUTH_LOGIN = "auth/login"
    const val AUTH_REGISTER = "auth/register"

    const val FEED_ME = "feed/me"
    const val FEED_ME_SESSION = "feed/me/session"

    const val SEARCH = "search"

    const val USER_ME = "user/me"
    const val USER_ME_PROFILE = "user/me/profile"
    const val USER_ME_PROFILE_EMAIL = "user/me/profile/email"
    const val USER_ME_PROFILE_PASSWORD = "user/me/profile/password"
    const val USER_ME_PREFERENCES = "user/me/preferences"
    const val USER_ME_POSTS = "user/me/posts"
    const val USER_ME_LIKES = "user/me/likes"
    const val USER_ME_INTERACTIONS = "user/me/interactions"
    const val USER_ME_BLOCKS = "user/me/blocks"
    const val USER_ME_EXPORT = "user/me/export"

    const val ADMIN_REPORTS = "admin/reports"

    fun graphNextPosts(postId: String): String =
        "graph/posts/${encodePathSegment(postId)}/next"

    fun adminReport(reportId: String): String =
        "admin/reports/${encodePathSegment(reportId)}"

    fun adminReports(status: String, reason: String? = null): String =
        withQuery(ADMIN_REPORTS, "status" to status, "reason" to reason)

    fun userProfile(username: String): String =
        "user/${encodePathSegment(username)}/profile"

    fun userPosts(username: String): String =
        "user/${encodePathSegment(username)}/posts"

    fun userPost(postId: String): String =
        "user/me/posts/${encodePathSegment(postId)}"

    fun userPostTopics(postId: String): String =
        "user/me/posts/${encodePathSegment(postId)}/topics"

    fun userPostTopic(postId: String, topic: String): String =
        "user/me/posts/${encodePathSegment(postId)}/topics/${encodePathSegment(topic)}"

    fun userInteractionLike(postId: String): String =
        "user/me/interactions/${encodePathSegment(postId)}/like"

    fun userBlock(username: String): String =
        "user/me/blocks/${encodePathSegment(username)}"

    /** Append non-null query params. Blank values are kept (e.g. `q=`); pass null to omit. */
    fun withQuery(path: String, vararg query: Pair<String, String?>): String {
        val parts = query.mapNotNull { (key, value) ->
            if (value == null) return@mapNotNull null
            "${encodeQuery(key)}=${encodeQuery(value)}"
        }
        if (parts.isEmpty()) return path
        return "$path?${parts.joinToString("&")}"
    }

    fun encodePathSegment(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20")

    private fun encodeQuery(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8)
}

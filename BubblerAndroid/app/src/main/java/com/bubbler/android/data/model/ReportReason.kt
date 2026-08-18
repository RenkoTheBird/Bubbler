package com.bubbler.android.data.model

/**
 * Why a user is reporting another person's post.
 * Matches Phase 0 hard-removal categories plus spam / other.
 */
enum class ReportReason(val title: String) {
    ILLEGAL_CONTENT("Illegal content"),
    SEVERE_VIOLENCE("Severe violence"),
    NON_CONSENSUAL_SEXUAL_CONTENT("Non-consensual sexual content"),
    HARASSMENT("Harassment or threats"),
    SPAM("Spam"),
    OTHER("Other"),
}

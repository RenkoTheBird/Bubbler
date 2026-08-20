package com.bubbler.android.data.model

/**
 * Why a user is reporting another person's post.
 * Matches Phase 0 hard-removal categories plus spam / other.
 * [ILLEGAL_CONTENT] is the severe-illegal / CSAM isolation bucket (escalation: L11).
 */
enum class ReportReason(val title: String, val apiValue: String) {
    ILLEGAL_CONTENT("Illegal content", "illegal_content"),
    SEVERE_VIOLENCE("Severe violence", "severe_violence"),
    NON_CONSENSUAL_SEXUAL_CONTENT("Non-consensual sexual content", "non_consensual_sexual_content"),
    HARASSMENT("Harassment or threats", "harassment"),
    SPAM("Spam", "spam"),
    OTHER("Other", "other"),
}

/** Cap for untrusted reporter notes; matches backend `DETAILS_MAX_LENGTH`. */
object ReportDetailsLimits {
    const val MAX_LENGTH = 2000
}

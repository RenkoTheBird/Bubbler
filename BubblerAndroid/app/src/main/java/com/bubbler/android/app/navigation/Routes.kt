package com.bubbler.android.app.navigation

/**
 * Route constants for root and nested navigation graphs.
 *
 * Mirrors SwiftUI `NavigationStack` destinations used by auth and the main tab shell.
 */
object Routes {
    // Auth graph (signed-out)
    const val LOGIN = "login"
    const val CREATE_ACCOUNT = "create_account"

    // Root signed-in shell
    const val MAIN = "main"

    // Feed tab nested stack (graph ↔ ranked home + create post + user profile)
    const val FEED_HOME = "feed_home"
    const val CREATE_POST = "create_post"

    // Profile tab nested stack
    const val PROFILE_HOME = "profile_home"
    const val BUBBLE_TRAIL = "bubble_trail"

    // Settings tab nested stack
    const val SETTINGS_HOME = "settings_home"
    const val SETTINGS_PROFILE_INFO = "settings_profile_info"
    const val SETTINGS_EMAIL = "settings_email"
    const val SETTINGS_PASSWORD = "settings_password"
    const val SETTINGS_DELETE_ACCOUNT = "settings_delete_account"
    const val SETTINGS_PREFERENCES = "settings_preferences"
    const val SETTINGS_PREFERENCES_ADVANCED = "settings_preferences_advanced"
    const val SETTINGS_BLOCKED = "settings_blocked"
    const val SETTINGS_REPORTS = "settings_reports"
    const val SETTINGS_REPORT_DETAIL = "settings_report/{reportId}"

    // Shared public profile (pushed from Feed / Search / Profile stacks)
    const val USER_PROFILE = "user_profile/{username}"

    fun userProfile(username: String): String {
        val encoded = java.net.URLEncoder.encode(username, Charsets.UTF_8.name())
        return "user_profile/$encoded"
    }

    fun settingsReportDetail(reportId: String): String {
        val encoded = java.net.URLEncoder.encode(reportId, Charsets.UTF_8.name())
        return "settings_report/$encoded"
    }
}

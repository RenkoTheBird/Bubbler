package com.bubbler.android.features.profile

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient

/**
 * Public profile for another user — mirrors Swift `UserProfileView`.
 *
 * Forwards to the shared [ProfileScreen] loader with [username].
 */
@Composable
fun UserProfileScreen(
    username: String,
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    ProfileScreen(
        authSession = authSession,
        apiClient = apiClient,
        targetUsername = username,
        onBack = onBack,
        onAuthorClick = onAuthorClick,
        onOpenBubbleTrail = null,
        modifier = modifier,
    )
}

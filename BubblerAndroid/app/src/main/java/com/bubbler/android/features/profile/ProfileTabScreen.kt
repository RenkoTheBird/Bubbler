package com.bubbler.android.features.profile

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.bubbler.android.app.navigation.Routes
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

/**
 * Profile tab shell — own profile, bubble trail, and pushed public profiles.
 */
@Composable
fun ProfileTabScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    modifier: Modifier = Modifier,
    navController: NavHostController = rememberNavController(),
) {
    NavHost(
        navController = navController,
        startDestination = Routes.PROFILE_HOME,
        modifier = modifier.fillMaxSize(),
    ) {
        composable(Routes.PROFILE_HOME) {
            MyProfileScreen(
                authSession = authSession,
                apiClient = apiClient,
                onOpenBubbleTrail = { navController.navigate(Routes.BUBBLE_TRAIL) },
                onAuthorClick = { username ->
                    navController.navigate(Routes.userProfile(username))
                },
            )
        }
        composable(Routes.BUBBLE_TRAIL) {
            BubbleTrailScreen(
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
            )
        }
        composable(
            route = Routes.USER_PROFILE,
            arguments = listOf(navArgument("username") { type = NavType.StringType }),
        ) { entry ->
            val encoded = entry.arguments?.getString("username").orEmpty()
            val username = URLDecoder.decode(encoded, StandardCharsets.UTF_8.name())
            UserProfileScreen(
                username = username,
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
                onAuthorClick = { next ->
                    if (!next.equals(username, ignoreCase = true)) {
                        navController.navigate(Routes.userProfile(next))
                    }
                },
            )
        }
    }
}
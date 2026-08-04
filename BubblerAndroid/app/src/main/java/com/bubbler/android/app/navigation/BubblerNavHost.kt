package com.bubbler.android.app.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.features.auth.CreateAccountScreen
import com.bubbler.android.features.auth.LoginScreen
import com.bubbler.android.features.home.MainTabScreen

/**
 * Root navigation — mirrors Swift `ContentView` auth gate + stacks.
 *
 * Signed-out: Login ↔ Create Account.
 * Signed-in: [MainTabScreen] (Feed / Search / Profile / Settings).
 */
@Composable
fun BubblerNavHost(
    authSession: AuthSession,
    apiClient: ApiClient,
) {
    val accessToken by authSession.accessToken.collectAsStateWithLifecycle()
    val isSignedIn = accessToken != null

    // Match Swift ContentView `.id(authSession.isSignedIn)` — rebuild the graph on auth flips.
    key(isSignedIn) {
        val navController = rememberNavController()

        if (isSignedIn) {
            NavHost(
                navController = navController,
                startDestination = Routes.MAIN,
            ) {
                composable(Routes.MAIN) {
                    MainTabScreen(
                        authSession = authSession,
                        apiClient = apiClient,
                    )
                }
            }
        } else {
            NavHost(
                navController = navController,
                startDestination = Routes.LOGIN,
            ) {
                composable(Routes.LOGIN) {
                    LoginScreen(
                        authSession = authSession,
                        apiClient = apiClient,
                        onCreateAccount = {
                            navController.navigate(Routes.CREATE_ACCOUNT)
                        },
                    )
                }
                composable(Routes.CREATE_ACCOUNT) {
                    CreateAccountScreen(
                        authSession = authSession,
                        onLogin = {
                            navController.popBackStack(Routes.LOGIN, inclusive = false)
                        },
                    )
                }
            }
        }
    }
}

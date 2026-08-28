package com.bubbler.android.app.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.auth.OnboardingGate
import com.bubbler.android.features.auth.CreateAccountScreen
import com.bubbler.android.features.auth.LoginScreen
import com.bubbler.android.features.home.MainTabScreen
import com.bubbler.android.features.onboarding.OnboardingScreen

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
    val onboardingGate by authSession.onboardingGate.collectAsStateWithLifecycle()
    val isSignedIn = accessToken != null

    // Match Swift ContentView `.id(authSession.isSignedIn)` — rebuild the graph on auth flips.
    key(isSignedIn) {
        val navController = rememberNavController()

        if (isSignedIn) {
            when (onboardingGate) {
                OnboardingGate.Unknown -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                    }
                }
                OnboardingGate.Required -> {
                    OnboardingScreen(
                        authSession = authSession,
                        apiClient = apiClient,
                    )
                }
                OnboardingGate.Complete -> {
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

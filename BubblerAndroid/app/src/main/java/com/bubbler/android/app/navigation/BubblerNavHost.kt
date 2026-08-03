package com.bubbler.android.app.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.features.auth.CreateAccountScreen
import com.bubbler.android.features.auth.LoginScreen

@Composable
fun BubblerNavHost(
    authSession: AuthSession,
    apiClient: ApiClient,
    navController: NavHostController = rememberNavController(),
) {
    val accessToken by authSession.accessToken.collectAsStateWithLifecycle()
    val userId by authSession.userId.collectAsStateWithLifecycle()
    val isSignedIn = accessToken != null

    if (isSignedIn) {
        SignedInPlaceholder(
            userId = userId,
            onSignOut = { authSession.signOut() },
        )
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

/**
 * Temporary signed-in shell until Phase 5 MainTabScreen.
 * Sign-out here proves TokenStore clear for Phase 1 exit criteria.
 */
@Composable
private fun SignedInPlaceholder(
    userId: Int?,
    onSignOut: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "Bubbler",
            style = MaterialTheme.typography.headlineLarge,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = if (userId != null) "Signed in · user #$userId" else "Signed in",
            style = MaterialTheme.typography.bodyLarge,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Main tabs arrive in Phase 5.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
        )
        Spacer(modifier = Modifier.height(24.dp))
        Button(onClick = onSignOut) {
            Text("Sign out")
        }
    }
}

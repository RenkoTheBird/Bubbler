package com.bubbler.android.app

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.bubbler.android.app.navigation.BubblerNavHost
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository
import kotlinx.coroutines.delay

@Composable
fun BubblerApp(
    apiClient: ApiClient = remember { ApiClient() },
    authSession: AuthSession? = null,
) {
    val context = LocalContext.current
    val session = authSession ?: remember {
        val tokenStore = TokenStore(context.applicationContext)
        AuthSession(
            tokenStore = tokenStore,
            authRepository = AuthRepository(apiClient),
            userRepository = UserRepository(apiClient, tokenStore),
            preferencesRepository = PreferencesRepository(apiClient, tokenStore),
        )
    }

    val successMessage by session.successMessage.collectAsStateWithLifecycle()
    val accessToken by session.accessToken.collectAsStateWithLifecycle()

    LaunchedEffect(accessToken) {
        if (accessToken != null) {
            session.refreshStaffAccess()
            session.refreshOnboardingStatus()
        }
    }

    LaunchedEffect(successMessage) {
        if (successMessage != null) {
            delay(2_000)
            session.clearSuccessMessage()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        BubblerNavHost(
            authSession = session,
            apiClient = apiClient,
        )

        AnimatedVisibility(
            visible = successMessage != null,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 18.dp),
            enter = slideInVertically() + fadeIn(),
            exit = slideOutVertically() + fadeOut(),
        ) {
            Surface(
                shape = RoundedCornerShape(50),
                color = Color(0xEB2E7D32),
                shadowElevation = 6.dp,
            ) {
                Text(
                    text = successMessage.orEmpty(),
                    modifier = Modifier.padding(horizontal = 18.dp, vertical = 12.dp),
                    color = Color.White,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

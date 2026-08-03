package com.bubbler.android.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.ui.components.BubblerLogo
import com.bubbler.android.features.auth.components.AuthErrorText
import com.bubbler.android.features.auth.components.AuthGradientBackground
import com.bubbler.android.features.auth.components.AuthLabeledField
import com.bubbler.android.features.auth.components.AuthOnGradient
import com.bubbler.android.features.auth.components.AuthPrimaryButton
import com.bubbler.android.features.auth.components.AuthSubtitle
import com.bubbler.android.features.auth.components.AuthTitle
import kotlinx.coroutines.launch

private sealed interface BackendStatus {
    data object Checking : BackendStatus
    data object Connected : BackendStatus
    data object Unavailable : BackendStatus
}

@Composable
fun LoginScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onCreateAccount: () -> Unit,
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var backendStatus by remember { mutableStateOf<BackendStatus>(BackendStatus.Checking) }

    val authError by authSession.authError.collectAsStateWithLifecycle()
    val isWorking by authSession.isWorking.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    LaunchedEffect(apiClient) {
        backendStatus = BackendStatus.Checking
        backendStatus = try {
            val health = apiClient.health()
            if (health.status == "ok") BackendStatus.Connected else BackendStatus.Unavailable
        } catch (_: Exception) {
            BackendStatus.Unavailable
        }
    }

    AuthGradientBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Spacer(modifier = Modifier.height(48.dp))

            BubblerLogo(size = 120.dp)
            Spacer(modifier = Modifier.height(18.dp))
            AuthTitle("Bubbler")
            Spacer(modifier = Modifier.height(8.dp))
            AuthSubtitle("See what you actually care about")
            Spacer(modifier = Modifier.height(12.dp))
            BackendStatusRow(backendStatus)

            Spacer(modifier = Modifier.height(30.dp))

            AuthLabeledField(
                label = "Email",
                value = email,
                onValueChange = { email = it },
                placeholder = "Enter your email",
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Next,
                    autoCorrectEnabled = false,
                ),
            )
            Spacer(modifier = Modifier.height(16.dp))
            AuthLabeledField(
                label = "Password",
                value = password,
                onValueChange = { password = it },
                placeholder = "Enter your password",
                isPassword = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done,
                    autoCorrectEnabled = false,
                ),
            )

            if (authError != null) {
                Spacer(modifier = Modifier.height(12.dp))
                AuthErrorText(authError!!)
            }

            Spacer(modifier = Modifier.height(18.dp))
            AuthPrimaryButton(
                label = "Log In",
                isWorking = isWorking,
                onClick = {
                    scope.launch {
                        authSession.signIn(email = email, password = password)
                    }
                },
            )

            Spacer(modifier = Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "New to Bubbler?",
                    color = AuthOnGradient.copy(alpha = 0.8f),
                )
                TextButton(onClick = onCreateAccount) {
                    Text(
                        text = "Create account",
                        color = AuthOnGradient,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))
            Text(
                text = "Powered by interest-based bubbles",
                color = AuthOnGradient.copy(alpha = 0.6f),
                style = androidx.compose.material3.MaterialTheme.typography.bodySmall,
            )
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun BackendStatusRow(status: BackendStatus) {
    val (label, color) = when (status) {
        BackendStatus.Checking -> "Checking backend" to Color.Yellow
        BackendStatus.Connected -> "Backend connected" to Color(0xFF69F0AE)
        BackendStatus.Unavailable -> "Backend unavailable" to Color(0xFFFF8A80)
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Spacer(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(color),
        )
        Text(
            text = label,
            color = AuthOnGradient.copy(alpha = 0.85f),
            style = androidx.compose.material3.MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

package com.bubbler.android.features.settings.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.features.settings.SettingsHeader
import com.bubbler.android.features.settings.SettingsLoadingCard
import com.bubbler.android.features.settings.SettingsMessageCard
import com.bubbler.android.features.settings.SettingsSectionCard
import com.bubbler.android.features.settings.SettingsSubpageScaffold

/**
 * Read-only profile details — mirrors Swift `ProfileInformationView`.
 */
@Composable
fun ProfileInfoScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
) {
    val viewModel = rememberAccountViewModel(authSession, apiClient)
    val profile by viewModel.profile.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.loadProfile(loadErrorTitle = "Couldn't load profile")
    }

    SettingsSubpageScaffold(
        title = "Profile Information",
        onBack = onBack,
    ) {
        SettingsHeader(
            title = "Your Account",
            subtitle = "Username and account details from your Bubbler profile.",
        )

        errorMessage?.let { message ->
            SettingsMessageCard(
                title = "Couldn't load profile",
                message = message,
                tint = Color.Red,
            )
        }

        if (isLoading) {
            SettingsLoadingCard(message = "Fetching your profile.")
        } else {
            profile?.let { user ->
                SettingsSectionCard(title = "Profile Details") {
                    ProfileInfoRow(label = "Username", value = "@${user.username}")
                    ProfileInfoRow(
                        label = "Email",
                        value = user.email?.takeIf { it.isNotBlank() } ?: "—",
                    )
                    ProfileInfoRow(label = "Member since", value = viewModel.memberSinceText)
                }
            }
        }

        TextButton(
            onClick = {
                viewModel.reloadProfile(loadErrorTitle = "Couldn't load profile")
            },
        ) {
            Text(
                text = "Reload from Server",
                color = Color.White.copy(alpha = 0.78f),
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun ProfileInfoRow(
    label: String,
    value: String,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.6f),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = value,
            color = Color.White.copy(alpha = 0.95f),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

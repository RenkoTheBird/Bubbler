package com.bubbler.android.features.settings.account

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.features.settings.SettingsHeader
import com.bubbler.android.features.settings.SettingsLoadingCard
import com.bubbler.android.features.settings.SettingsMessageCard
import com.bubbler.android.features.settings.SettingsSectionCard
import com.bubbler.android.features.settings.SettingsSubpageScaffold

/**
 * Update sign-in email — mirrors Swift `EmailSettingsView`.
 */
@Composable
fun EmailSettingsScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
) {
    val viewModel = rememberAccountViewModel(authSession, apiClient)
    val email by viewModel.email.collectAsStateWithLifecycle()
    val currentEmail by viewModel.currentEmail.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()
    val errorTitle by viewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    val successMessage by viewModel.successMessage.collectAsStateWithLifecycle()

    val canSave = email.trim().isNotEmpty() &&
        !email.trim().equals(currentEmail, ignoreCase = true) &&
        !isSaving &&
        !isLoading

    LaunchedEffect(Unit) {
        viewModel.loadProfile(loadErrorTitle = "Couldn't load email")
    }

    SettingsSubpageScaffold(
        title = "Email Settings",
        onBack = onBack,
    ) {
        SettingsHeader(
            title = "Email Address",
            subtitle = "Update the email used to sign in to your Bubbler account.",
        )

        errorMessage?.let { message ->
            SettingsMessageCard(
                title = errorTitle,
                message = message,
                tint = Color.Red,
            )
        }

        successMessage?.let { message ->
            SettingsMessageCard(
                title = "Email updated",
                message = message,
                tint = Color(0xFF2E7D32),
            )
        }

        if (isLoading) {
            SettingsLoadingCard(message = "Fetching your current email.")
        } else {
            SettingsSectionCard(
                title = "Contact Email",
                subtitle = currentEmail.takeIf { it.isNotEmpty() }
                    ?.let { "Currently signed in as $it." },
            ) {
                SettingsFormField(
                    label = "Email",
                    value = email,
                    onValueChange = viewModel::updateEmail,
                    placeholder = "Enter your email",
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Done,
                        autoCorrectEnabled = false,
                    ),
                )
            }

            SettingsPrimaryButton(
                label = if (isSaving) "Saving..." else "Save Email",
                enabled = canSave,
                isWorking = isSaving,
                onClick = viewModel::saveEmail,
            )
        }
    }
}

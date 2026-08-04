package com.bubbler.android.features.settings.account

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
 * Permanent account deletion — mirrors Swift `DeleteAccountView`.
 * Verifies password via login, then deletes and signs out.
 */
@Composable
fun DeleteAccountScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
) {
    val viewModel = rememberAccountViewModel(authSession, apiClient)
    val deletePassword by viewModel.deletePassword.collectAsStateWithLifecycle()
    val currentEmail by viewModel.currentEmail.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isDeleting by viewModel.isDeleting.collectAsStateWithLifecycle()
    val errorTitle by viewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    var showDeleteConfirmation by remember { mutableStateOf(false) }

    val canDelete = deletePassword.isNotEmpty() &&
        currentEmail.isNotEmpty() &&
        !isDeleting &&
        !isLoading

    LaunchedEffect(Unit) {
        viewModel.loadProfile()
    }

    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text("Delete your account permanently?") },
            text = {
                Text(
                    "This will permanently remove your Bubbler account and data. This cannot be undone.",
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirmation = false
                        viewModel.deleteAccount()
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = Color.Red),
                ) {
                    Text("Delete Account")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) {
                    Text("Cancel")
                }
            },
        )
    }

    SettingsSubpageScaffold(
        title = "Delete Account",
        onBack = onBack,
    ) {
        SettingsHeader(
            title = "Delete Account",
            subtitle = "Permanently close your Bubbler account after confirming your password.",
        )

        errorMessage?.let { message ->
            SettingsMessageCard(
                title = errorTitle,
                message = message,
                tint = Color.Red,
            )
        }

        if (isLoading) {
            SettingsLoadingCard(message = "Preparing account deletion.")
        } else {
            SettingsSectionCard(
                title = "Before you continue",
                subtitle = currentEmail.takeIf { it.isNotEmpty() }
                    ?.let { "Signed in as $it." },
            ) {
                Text(
                    text = "Deleting your account removes your profile, posts, and preferences. This action is permanent.",
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            SettingsSectionCard(
                title = "Confirm Password",
                subtitle = "Retype your password to authorize account deletion.",
            ) {
                SettingsFormField(
                    label = "Password",
                    value = deletePassword,
                    onValueChange = viewModel::updateDeletePassword,
                    placeholder = "Enter your password",
                    isPassword = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Done,
                    ),
                )
            }

            SettingsPrimaryButton(
                label = if (isDeleting) "Deleting..." else "Delete Account",
                enabled = canDelete,
                isWorking = isDeleting,
                destructive = true,
                onClick = { showDeleteConfirmation = true },
            )
        }
    }
}

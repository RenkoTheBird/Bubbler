package com.bubbler.android.features.settings.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
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
 * Password reset — mirrors Swift `PasswordSecurityView`.
 * Successful reset signs the user out (same as iOS).
 */
@Composable
fun PasswordSecurityScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
) {
    val viewModel = rememberAccountViewModel(authSession, apiClient)
    val emailOrUsername by viewModel.emailOrUsername.collectAsStateWithLifecycle()
    val currentPassword by viewModel.currentPassword.collectAsStateWithLifecycle()
    val newPassword by viewModel.newPassword.collectAsStateWithLifecycle()
    val confirmNewPassword by viewModel.confirmNewPassword.collectAsStateWithLifecycle()
    val currentEmail by viewModel.currentEmail.collectAsStateWithLifecycle()
    val accountUsername by viewModel.accountUsername.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()
    val errorTitle by viewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    var showResetConfirmation by remember { mutableStateOf(false) }

    val canReset = emailOrUsername.trim().isNotEmpty() &&
        currentPassword.isNotEmpty() &&
        newPassword.isNotEmpty() &&
        confirmNewPassword.isNotEmpty() &&
        !isSaving &&
        !isLoading

    val accountSubtitle = when {
        currentEmail.isNotEmpty() -> "Signed in as $currentEmail."
        accountUsername.isNotEmpty() -> "Signed in as @$accountUsername."
        else -> null
    }

    LaunchedEffect(Unit) {
        viewModel.loadProfile()
    }

    if (showResetConfirmation) {
        AlertDialog(
            onDismissRequest = { showResetConfirmation = false },
            title = { Text("Reset your password?") },
            text = {
                Text("You will be logged out and must sign in again with your new password.")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showResetConfirmation = false
                        viewModel.resetPassword()
                    },
                ) {
                    Text("Reset Password")
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetConfirmation = false }) {
                    Text("Cancel")
                }
            },
        )
    }

    SettingsSubpageScaffold(
        title = "Password & Security",
        onBack = onBack,
    ) {
        SettingsHeader(
            title = "Password & Security",
            subtitle = "Reset your password after confirming your account details.",
        )

        errorMessage?.let { message ->
            SettingsMessageCard(
                title = errorTitle,
                message = message,
                tint = Color.Red,
            )
        }

        if (isLoading) {
            SettingsLoadingCard(message = "Preparing password reset.")
        } else {
            SettingsSectionCard(
                title = "You'll be signed out",
                subtitle = accountSubtitle,
            ) {
                Text(
                    text = "After a successful reset, your session ends immediately. Log back in with your new password to continue.",
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            SettingsSectionCard(
                title = "Reset Password",
                subtitle = "Confirm your identity, then choose a new password.",
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    SettingsFormField(
                        label = "Current Email or Username",
                        value = emailOrUsername,
                        onValueChange = viewModel::updateEmailOrUsername,
                        placeholder = "Enter your email or username",
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Email,
                            imeAction = ImeAction.Next,
                            autoCorrectEnabled = false,
                        ),
                    )
                    SettingsFormField(
                        label = "Current Password",
                        value = currentPassword,
                        onValueChange = viewModel::updateCurrentPassword,
                        placeholder = "Enter your current password",
                        isPassword = true,
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Next,
                        ),
                    )
                    SettingsFormField(
                        label = "New Password",
                        value = newPassword,
                        onValueChange = viewModel::updateNewPassword,
                        placeholder = "Create a new password",
                        isPassword = true,
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Next,
                        ),
                    )
                    SettingsFormField(
                        label = "Confirm New Password",
                        value = confirmNewPassword,
                        onValueChange = viewModel::updateConfirmNewPassword,
                        placeholder = "Re-enter your new password",
                        isPassword = true,
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Done,
                        ),
                    )
                }
            }

            SettingsPrimaryButton(
                label = if (isSaving) "Resetting..." else "Reset Password",
                enabled = canReset,
                isWorking = isSaving,
                onClick = { showResetConfirmation = true },
            )
        }
    }
}

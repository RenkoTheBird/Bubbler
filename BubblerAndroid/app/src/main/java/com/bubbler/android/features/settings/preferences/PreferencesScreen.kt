package com.bubbler.android.features.settings.preferences

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.features.settings.SettingsHeader
import com.bubbler.android.features.settings.SettingsLoadingCard
import com.bubbler.android.features.settings.SettingsMessageCard
import com.bubbler.android.features.settings.SettingsSectionCard
import com.bubbler.android.features.settings.SettingsSubpageScaffold
import com.bubbler.android.features.settings.account.SettingsPrimaryButton
import com.bubbler.android.ui.components.FeedPresetPicker
import com.bubbler.android.ui.components.PreferenceTopicsEditor
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.NotInterested

/**
 * Recommendation preferences editor — mirrors Swift `PreferencesSettingsView`.
 */
@Composable
fun PreferencesScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
    onOpenAdvanced: () -> Unit,
    sharedViewModel: PreferencesViewModel? = null,
) {
    val context = LocalContext.current
    val factory = remember(authSession, apiClient, context) {
        PreferencesViewModelFactory(
            authSession = authSession,
            preferencesRepository = PreferencesRepository(
                apiClient = apiClient,
                tokenStore = TokenStore(context.applicationContext),
            ),
        )
    }
    val resolvedViewModel: PreferencesViewModel = sharedViewModel ?: viewModel(factory = factory)

    val preferences by resolvedViewModel.preferences.collectAsStateWithLifecycle()
    val isLoading by resolvedViewModel.isLoading.collectAsStateWithLifecycle()
    val isSaving by resolvedViewModel.isSaving.collectAsStateWithLifecycle()
    val errorTitle by resolvedViewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by resolvedViewModel.errorMessage.collectAsStateWithLifecycle()
    val successMessage by resolvedViewModel.successMessage.collectAsStateWithLifecycle()

    LaunchedEffect(resolvedViewModel) {
        resolvedViewModel.refreshFromServerAwait()
    }

    SettingsSubpageScaffold(
        title = "Preferences",
        onBack = onBack,
    ) {
        SettingsHeader(
            title = "Recommendation Preferences",
            subtitle = "Choose how your bubble explores topics and posts.",
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
                title = "Preferences updated",
                message = message,
                tint = Color(0xFF2E7D32),
            )
        }

        if (isLoading) {
            SettingsLoadingCard(message = "Fetching your saved preference profile.")
        } else {
            SettingsSectionCard(
                title = "Feed Composition",
                subtitle = "Pick a preset that matches how you want to explore.",
            ) {
                FeedPresetPicker(
                    selectedPreset = preferences.feedPreset,
                    onSelect = resolvedViewModel::selectPreset,
                )

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onOpenAdvanced)
                        .padding(top = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Advanced feed settings",
                        color = Color.White.copy(alpha = 0.9f),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f),
                    )
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.55f),
                    )
                }
            }

            SettingsSectionCard(
                title = "Recency",
                subtitle = "Boost newer posts when ranking candidates.",
            ) {
                PreferenceToggleRow(
                    label = "Prioritize Recent Posts",
                    checked = preferences.useRecency,
                    onCheckedChange = resolvedViewModel::updateUseRecency,
                    tint = Color(0xFFFF9800),
                )
            }

            PreferenceTopicsEditor(
                title = "Preferred Topics",
                subtitle = "Search existing topics to give them extra weight in your bubble.",
                icon = Icons.Filled.Favorite,
                iconColor = Color(0xFFEC407A),
                topics = preferences.preferredTopics,
                onTopicsChange = resolvedViewModel::updatePreferredTopics,
                conflictingTopics = preferences.blacklistedTopics,
                onConflictingTopicsChange = resolvedViewModel::updateBlacklistedTopics,
            )

            PreferenceTopicsEditor(
                title = "Blacklisted Topics",
                subtitle = "Search existing topics to filter them out of your recommendations.",
                icon = Icons.Filled.NotInterested,
                iconColor = Color(0xFFFF9800),
                topics = preferences.blacklistedTopics,
                onTopicsChange = resolvedViewModel::updateBlacklistedTopics,
                conflictingTopics = preferences.preferredTopics,
                onConflictingTopicsChange = resolvedViewModel::updatePreferredTopics,
            )

            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SettingsPrimaryButton(
                    label = if (isSaving) "Saving..." else "Save Preferences",
                    enabled = !isSaving,
                    isWorking = isSaving,
                    onClick = resolvedViewModel::savePreferences,
                )

                TextButton(
                    onClick = resolvedViewModel::restoreDefaults,
                    enabled = !isSaving,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(18.dp))
                        .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(18.dp)),
                ) {
                    Text(
                        text = "Restore Defaults",
                        color = Color.White.copy(alpha = 0.9f),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(vertical = 6.dp),
                    )
                }

                TextButton(
                    onClick = resolvedViewModel::reloadPreferences,
                    enabled = !isSaving,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = "Reload from Server",
                        color = Color.White.copy(alpha = 0.78f),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
    }
}

@Composable
private fun PreferenceToggleRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    tint: Color,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.9f),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = tint,
                uncheckedThumbColor = Color.White.copy(alpha = 0.9f),
                uncheckedTrackColor = Color.White.copy(alpha = 0.25f),
            ),
        )
    }
}

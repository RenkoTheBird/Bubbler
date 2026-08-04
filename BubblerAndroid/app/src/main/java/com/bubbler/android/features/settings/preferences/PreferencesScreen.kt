package com.bubbler.android.features.settings.preferences

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.NotInterested
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
import androidx.compose.ui.text.font.FontFamily
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
import com.bubbler.android.ui.components.PreferenceSliderRow
import com.bubbler.android.ui.components.PreferenceTopicsEditor
import kotlin.math.roundToInt

/**
 * Recommendation preferences editor — mirrors Swift `PreferencesSettingsView`.
 */
@Composable
fun PreferencesScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
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
    val viewModel: PreferencesViewModel = viewModel(factory = factory)

    val preferences by viewModel.preferences.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()
    val errorTitle by viewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    val successMessage by viewModel.successMessage.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.refreshFromServerAwait()
    }

    SettingsSubpageScaffold(
        title = "Preferences",
        onBack = onBack,
    ) {
        SettingsHeader(
            title = "Recommendation Preferences",
            subtitle = "Tune how much variety, randomness, and topic weighting shape your feed.",
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
                title = "Core Tuning",
                subtitle = "Higher diversity broadens your bubble. Higher randomness introduces more unexpected posts.",
            ) {
                PreferenceSliderRow(
                    title = "Diversity",
                    value = preferences.diversityTolerance.toFloat(),
                    onValueChange = { viewModel.updateDiversity(it.toDouble()) },
                    tint = Color.Cyan,
                )
                PreferenceSliderRow(
                    title = "Randomness",
                    value = preferences.randomness.toFloat(),
                    onValueChange = { viewModel.updateRandomness(it.toDouble()) },
                    tint = Color(0xFFAB47BC),
                )
                PreferenceToggleRow(
                    label = "Boost Recent Posts",
                    checked = preferences.useRecency,
                    onCheckedChange = viewModel::updateUseRecency,
                    tint = Color(0xFFFF9800),
                )
            }

            SettingsSectionCard(
                title = "Feed Composition",
                subtitle = "These weights are normalized automatically when you save.",
            ) {
                PreferenceSliderRow(
                    title = "Similar",
                    value = preferences.strategyWeights.similar.toFloat(),
                    onValueChange = {
                        viewModel.updateStrategyWeights { weights ->
                            weights.copy(similar = it.toDouble())
                        }
                    },
                    tint = Color(0xFF42A5F5),
                )
                PreferenceSliderRow(
                    title = "Graph",
                    value = preferences.strategyWeights.graph.toFloat(),
                    onValueChange = {
                        viewModel.updateStrategyWeights { weights ->
                            weights.copy(graph = it.toDouble())
                        }
                    },
                    tint = Color(0xFF26A69A),
                )
                PreferenceSliderRow(
                    title = "Opposite",
                    value = preferences.strategyWeights.opposite.toFloat(),
                    onValueChange = {
                        viewModel.updateStrategyWeights { weights ->
                            weights.copy(opposite = it.toDouble())
                        }
                    },
                    tint = Color(0xFF5C6BC0),
                )
                PreferenceSliderRow(
                    title = "Random",
                    value = preferences.strategyWeights.random.toFloat(),
                    onValueChange = {
                        viewModel.updateStrategyWeights { weights ->
                            weights.copy(random = it.toDouble())
                        }
                    },
                    tint = Color(0xFFEC407A),
                )
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "Current total",
                        color = Color.White.copy(alpha = 0.65f),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = "${(preferences.strategyWeights.total * 100.0).roundToInt()}%",
                        color = Color.White.copy(alpha = 0.75f),
                        style = MaterialTheme.typography.labelMedium,
                        fontFamily = FontFamily.Monospace,
                    )
                }
            }

            PreferenceTopicsEditor(
                title = "Preferred Topics",
                subtitle = "Search existing topics to give them extra weight in your bubble.",
                icon = Icons.Filled.Favorite,
                iconColor = Color(0xFFEC407A),
                topics = preferences.preferredTopics,
                onTopicsChange = viewModel::updatePreferredTopics,
                conflictingTopics = preferences.blacklistedTopics,
                onConflictingTopicsChange = viewModel::updateBlacklistedTopics,
            )

            PreferenceTopicsEditor(
                title = "Blacklisted Topics",
                subtitle = "Search existing topics to filter them out of your recommendations.",
                icon = Icons.Filled.NotInterested,
                iconColor = Color(0xFFFF9800),
                topics = preferences.blacklistedTopics,
                onTopicsChange = viewModel::updateBlacklistedTopics,
                conflictingTopics = preferences.preferredTopics,
                onConflictingTopicsChange = viewModel::updatePreferredTopics,
            )

            SettingsSectionCard(
                title = "AI Topic Detection",
                subtitle = if (PreferencesViewModel.IS_AI_TOPIC_DETECTION_AVAILABLE) {
                    "When enabled, your topic classifications can help train smarter topic suggestions."
                } else {
                    "Coming soon. Topic training contributions and AI suggestions are not available yet."
                },
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = "Contribute Topic Classifications",
                            color = Color.White.copy(
                                alpha = if (PreferencesViewModel.IS_AI_TOPIC_DETECTION_AVAILABLE) {
                                    0.9f
                                } else {
                                    0.55f
                                },
                            ),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        if (!PreferencesViewModel.IS_AI_TOPIC_DETECTION_AVAILABLE) {
                            Text(
                                text = "Unavailable",
                                color = Color.White.copy(alpha = 0.45f),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                    Switch(
                        checked = if (PreferencesViewModel.IS_AI_TOPIC_DETECTION_AVAILABLE) {
                            preferences.aiTopicDetection
                        } else {
                            false
                        },
                        onCheckedChange = viewModel::updateAiTopicDetection,
                        enabled = PreferencesViewModel.IS_AI_TOPIC_DETECTION_AVAILABLE,
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = Color.White,
                            checkedTrackColor = Color(0xFF26A69A),
                            uncheckedThumbColor = Color.White.copy(alpha = 0.9f),
                            uncheckedTrackColor = Color.White.copy(alpha = 0.25f),
                            disabledCheckedThumbColor = Color.White.copy(alpha = 0.55f),
                            disabledCheckedTrackColor = Color(0xFF26A69A).copy(alpha = 0.35f),
                            disabledUncheckedThumbColor = Color.White.copy(alpha = 0.45f),
                            disabledUncheckedTrackColor = Color.White.copy(alpha = 0.12f),
                        ),
                    )
                }
            }

            SettingsSectionCard(
                title = "Behavior Signals",
                subtitle = "Enable view-time feedback if you want watch time to influence recommendations.",
            ) {
                PreferenceToggleRow(
                    label = "Use View Time",
                    checked = preferences.useViewTime,
                    onCheckedChange = viewModel::updateUseViewTime,
                    tint = Color.Cyan,
                )
                PreferenceSliderRow(
                    title = "View Time Weight",
                    value = preferences.viewTimeWeight.toFloat(),
                    onValueChange = { viewModel.updateViewTimeWeight(it.toDouble()) },
                    tint = Color(0xFF66BB6A),
                    enabled = preferences.useViewTime,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                SettingsPrimaryButton(
                    label = if (isSaving) "Saving..." else "Save Preferences",
                    enabled = !isSaving,
                    isWorking = isSaving,
                    onClick = viewModel::savePreferences,
                )

                TextButton(
                    onClick = viewModel::restoreDefaults,
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
                    onClick = viewModel::reloadPreferences,
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

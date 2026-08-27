package com.bubbler.android.features.settings.preferences

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.bubbler.android.features.settings.SettingsHeader
import com.bubbler.android.features.settings.SettingsMessageCard
import com.bubbler.android.features.settings.SettingsSectionCard
import com.bubbler.android.features.settings.SettingsSubpageScaffold
import com.bubbler.android.features.settings.account.SettingsPrimaryButton
import com.bubbler.android.ui.components.PreferenceSliderRow
import kotlin.math.roundToInt

@Composable
fun PreferencesAdvancedScreen(
    viewModel: PreferencesViewModel,
    onBack: () -> Unit,
) {
    val preferences by viewModel.preferences.collectAsStateWithLifecycle()
    val isSaving by viewModel.isSaving.collectAsStateWithLifecycle()
    val errorTitle by viewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    val successMessage by viewModel.successMessage.collectAsStateWithLifecycle()

    SettingsSubpageScaffold(
        title = "Advanced",
        onBack = onBack,
    ) {
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

        SettingsSectionCard(
            title = "Topic Composition",
            subtitle = "How your walk chooses the next topics.",
        ) {
            PreferenceSliderRow(
                title = "Similar",
                value = preferences.topicComposition.similar.toFloat(),
                onValueChange = { viewModel.updateTopicComposition(similar = it.toDouble()) },
                tint = Color(0xFF42A5F5),
            )
            PreferenceSliderRow(
                title = "Opposite",
                value = preferences.topicComposition.opposite.toFloat(),
                onValueChange = { viewModel.updateTopicComposition(opposite = it.toDouble()) },
                tint = Color(0xFF5C6BC0),
            )
            PreferenceSliderRow(
                title = "Surprise",
                value = preferences.topicComposition.surprise.toFloat(),
                onValueChange = { viewModel.updateTopicComposition(surprise = it.toDouble()) },
                tint = Color(0xFFEC407A),
            )
            CompositionTotalRow(total = viewModel.topicCompositionTotal)
        }

        SettingsSectionCard(
            title = "Post Composition",
            subtitle = "How posts are chosen within each topic.",
        ) {
            PreferenceSliderRow(
                title = "Similar",
                value = preferences.postComposition.similar.toFloat(),
                onValueChange = { viewModel.updatePostComposition(similar = it.toDouble()) },
                tint = Color(0xFF26A69A),
            )
            PreferenceSliderRow(
                title = "Opposite",
                value = preferences.postComposition.opposite.toFloat(),
                onValueChange = { viewModel.updatePostComposition(opposite = it.toDouble()) },
                tint = Color(0xFFAB47BC),
            )
            PreferenceSliderRow(
                title = "Surprise",
                value = preferences.postComposition.surprise.toFloat(),
                onValueChange = { viewModel.updatePostComposition(surprise = it.toDouble()) },
                tint = Color(0xFFFF9800),
            )
            CompositionTotalRow(total = viewModel.postCompositionTotal)
        }

        SettingsSectionCard(
            title = "Behavior Signals",
            subtitle = "Optional signals that refine recommendations over time.",
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
                    ),
                )
            }
        }

        SettingsPrimaryButton(
            label = if (isSaving) "Saving..." else "Save Preferences",
            enabled = !isSaving,
            isWorking = isSaving,
            onClick = viewModel::savePreferences,
        )
    }
}

@Composable
private fun CompositionTotalRow(total: Double) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Current total",
            color = Color.White.copy(alpha = 0.65f),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = "${(total * 100.0).roundToInt()}%",
            color = Color.White.copy(alpha = 0.75f),
            style = MaterialTheme.typography.labelMedium,
            fontFamily = FontFamily.Monospace,
        )
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

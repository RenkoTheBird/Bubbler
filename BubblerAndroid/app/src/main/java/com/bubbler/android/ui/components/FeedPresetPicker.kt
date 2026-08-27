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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.bubbler.android.data.model.FeedPreset
import com.bubbler.android.data.model.UserPreferences
import com.bubbler.android.data.model.displayDescription
import com.bubbler.android.data.model.displayTitle

@Composable
fun FeedPresetPicker(
    selectedPreset: FeedPreset,
    onSelect: (FeedPreset) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        UserPreferences.SELECTABLE_PRESETS.forEach { preset ->
            val isSelected = selectedPreset == preset
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSelect(preset) }
                    .background(
                        color = if (isSelected) {
                            Color.White.copy(alpha = 0.14f)
                        } else {
                            Color.White.copy(alpha = 0.06f)
                        },
                        shape = RoundedCornerShape(16.dp),
                    )
                    .border(
                        width = 1.dp,
                        color = if (isSelected) {
                            Color.Cyan.copy(alpha = 0.5f)
                        } else {
                            Color.White.copy(alpha = 0.12f)
                        },
                        shape = RoundedCornerShape(16.dp),
                    )
                    .padding(14.dp)
                    .semantics {
                        contentDescription = "${preset.displayTitle()}. ${preset.displayDescription()}"
                    },
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Icon(
                    imageVector = if (isSelected) {
                        Icons.Filled.CheckCircle
                    } else {
                        Icons.Filled.RadioButtonUnchecked
                    },
                    contentDescription = null,
                    tint = if (isSelected) Color.Cyan else Color.White.copy(alpha = 0.45f),
                )
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = preset.displayTitle(),
                        color = Color.White.copy(alpha = 0.95f),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = preset.displayDescription(),
                        color = Color.White.copy(alpha = 0.65f),
                        style = MaterialTheme.typography.labelMedium,
                    )
                }
            }
        }

        if (selectedPreset == FeedPreset.CUSTOM) {
            Text(
                text = "Using custom mix — adjust weights in Advanced feed settings.",
                color = Color.White.copy(alpha = 0.6f),
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

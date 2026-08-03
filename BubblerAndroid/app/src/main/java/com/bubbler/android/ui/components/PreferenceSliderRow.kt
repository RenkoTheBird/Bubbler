package com.bubbler.android.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bubbler.android.app.theme.BubblerTheme
import kotlin.math.roundToInt

/** Labeled 0…1 slider with percent readout — mirrors Swift `PreferenceSliderRow`. */
@Composable
fun PreferenceSliderRow(
    title: String,
    value: Float,
    onValueChange: (Float) -> Unit,
    tint: Color,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = title,
                color = Color.White.copy(alpha = 0.9f),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = "${(value * 100f).roundToInt()}%",
                color = Color.White.copy(alpha = 0.72f),
                style = MaterialTheme.typography.bodySmall,
                fontFamily = FontFamily.Monospace,
            )
        }

        Slider(
            value = value.coerceIn(0f, 1f),
            onValueChange = onValueChange,
            valueRange = 0f..1f,
            enabled = enabled,
            modifier = Modifier.fillMaxWidth(),
            colors = SliderDefaults.colors(
                thumbColor = tint,
                activeTrackColor = tint,
                inactiveTrackColor = Color.White.copy(alpha = 0.2f),
                disabledThumbColor = tint.copy(alpha = 0.45f),
                disabledActiveTrackColor = tint.copy(alpha = 0.45f),
            ),
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun PreferenceSliderRowPreview() {
    BubblerTheme {
        PreferenceSliderRow(
            title = "Diversity",
            value = 0.4f,
            onValueChange = {},
            tint = Color.Cyan,
            modifier = Modifier.padding(16.dp),
        )
    }
}

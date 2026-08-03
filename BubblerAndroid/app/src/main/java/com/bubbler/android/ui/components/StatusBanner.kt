package com.bubbler.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bubbler.android.app.theme.BubblerTheme

/**
 * Inline status / error chip used by graph and feed screens.
 * Extracted from Swift `GraphFeedView.banner`.
 */
@Composable
fun StatusBanner(
    message: String,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    Text(
        text = message,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(tint.copy(alpha = 0.22f))
            .border(1.dp, tint.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        color = Color.White.copy(alpha = 0.92f),
        style = MaterialTheme.typography.bodySmall,
    )
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun StatusBannerPreview() {
    BubblerTheme {
        StatusBanner(
            message = "Preferred topic: Technology.",
            tint = Color.Cyan.copy(alpha = 0.85f),
            modifier = Modifier.padding(16.dp),
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun StatusBannerErrorPreview() {
    BubblerTheme {
        StatusBanner(
            message = "Could not load the next bubble.",
            tint = Color.Red.copy(alpha = 0.8f),
            modifier = Modifier.padding(16.dp),
        )
    }
}

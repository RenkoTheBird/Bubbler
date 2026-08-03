package com.bubbler.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.bubbler.android.app.theme.BubblerTheme

/** Bubble-cluster brand mark — mirrors Swift `BubblerLogoView`. */
@Composable
fun BubblerLogo(
    modifier: Modifier = Modifier,
    size: Dp = 180.dp,
) {
    val scale = size / 180.dp
    Box(
        modifier = modifier.size(size),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(size)
                .clip(CircleShape)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            Color.Cyan.copy(alpha = 0.25f),
                            Color(0xFF2196F3).copy(alpha = 0.15f),
                            Color(0xFF2196F3).copy(alpha = 0.05f),
                            Color.Transparent,
                        ),
                    ),
                ),
        )

        LogoBubble(x = (-25).dp * scale, y = (-30).dp * scale, size = 38.dp * scale, opacity = 0.9f)
        LogoBubble(x = 15.dp * scale, y = (-45).dp * scale, size = 22.dp * scale, opacity = 0.7f)
        LogoBubble(x = 35.dp * scale, y = (-10).dp * scale, size = 26.dp * scale, opacity = 0.75f)
        LogoBubble(x = (-35).dp * scale, y = 15.dp * scale, size = 30.dp * scale, opacity = 0.8f)
        LogoBubble(x = 10.dp * scale, y = 25.dp * scale, size = 40.dp * scale, opacity = 0.85f)
        LogoBubble(x = 45.dp * scale, y = 35.dp * scale, size = 20.dp * scale, opacity = 0.65f)
        LogoBubble(x = (-10).dp * scale, y = 55.dp * scale, size = 24.dp * scale, opacity = 0.7f)
        LogoBubble(
            x = 5.dp * scale,
            y = 5.dp * scale,
            size = 18.dp * scale,
            opacity = 1.0f,
            highlight = true,
        )
    }
}

@Composable
private fun LogoBubble(
    x: Dp,
    y: Dp,
    size: Dp,
    opacity: Float,
    highlight: Boolean = false,
) {
    Box(
        modifier = Modifier
            .offset(x = x, y = y)
            .size(size)
            .then(
                if (highlight) {
                    Modifier.shadow(
                        elevation = 6.dp,
                        shape = CircleShape,
                        ambientColor = Color.White.copy(alpha = 0.3f),
                        spotColor = Color.White.copy(alpha = 0.3f),
                    )
                } else {
                    Modifier.shadow(
                        elevation = 4.dp,
                        shape = CircleShape,
                        ambientColor = Color(0xFF2196F3).copy(alpha = 0.15f),
                        spotColor = Color(0xFF2196F3).copy(alpha = 0.15f),
                    )
                },
            )
            .clip(CircleShape)
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.White.copy(alpha = opacity),
                        Color.Cyan.copy(alpha = opacity * 0.6f),
                        Color(0xFF2196F3).copy(alpha = opacity * 0.8f),
                    ),
                ),
            )
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.80f),
                shape = CircleShape,
            )
            .blur(0.2.dp),
    )
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun BubblerLogoPreview() {
    BubblerTheme {
        BubblerLogo()
    }
}

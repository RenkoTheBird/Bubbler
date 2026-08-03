package com.bubbler.android.app.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = BubblerBlue,
    onPrimary = Color.White,
    secondary = BubblerSky,
    onSecondary = BubblerInk,
    background = BubblerFoam,
    onBackground = BubblerInk,
    surface = Color.White,
    onSurface = BubblerInk,
    error = BubblerError,
)

private val DarkColors = darkColorScheme(
    primary = BubblerSky,
    onPrimary = BubblerInk,
    secondary = BubblerBlue,
    onSecondary = Color.White,
    background = BubblerInk,
    onBackground = BubblerFoam,
    surface = Color(0xFF16344A),
    onSurface = BubblerFoam,
    error = BubblerError,
)

@Composable
fun BubblerTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = BubblerTypography,
        content = content,
    )
}

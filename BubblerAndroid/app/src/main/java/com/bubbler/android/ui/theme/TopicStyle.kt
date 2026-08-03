package com.bubbler.android.ui.theme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Eco
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.SportsBasketball
import androidx.compose.material.icons.filled.Work
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector

/** Topic accent colors and icons — mirrors Swift `TopicStyle` in `TopicPicker.swift`. */
object TopicStyle {
    fun icon(topic: String): ImageVector =
        when (topic.lowercase()) {
            "technology" -> Icons.Filled.Computer
            "science" -> Icons.Filled.Public
            "sports" -> Icons.Filled.SportsBasketball
            "politics" -> Icons.Filled.AccountBalance
            "entertainment" -> Icons.Filled.Movie
            "business" -> Icons.Filled.Work
            "health" -> Icons.Filled.Favorite
            "education" -> Icons.AutoMirrored.Filled.MenuBook
            "environment" -> Icons.Filled.Eco
            else -> Icons.Filled.Apps
        }

    fun color(topic: String): Color =
        when (topic.lowercase()) {
            "technology" -> Color(0xFF2196F3) // blue
            "science" -> Color(0xFF9C27B0) // purple
            "sports" -> Color(0xFF4CAF50) // green
            "politics" -> Color(0xFFF44336) // red
            "entertainment" -> Color(0xFFE91E63) // pink
            "business" -> Color(0xFF3F51B5) // indigo
            "health" -> Color(0xFF00BFA5) // mint
            "education" -> Color(0xFFFF9800) // orange
            "environment" -> Color(0xFF009688) // teal
            else -> Color(0xFF00BCD4) // cyan
        }
}

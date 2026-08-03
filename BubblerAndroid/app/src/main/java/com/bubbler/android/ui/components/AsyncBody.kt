package com.bubbler.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bubbler.android.app.theme.BubblerTheme

/**
 * Loading / empty / error shell used across feed, graph, search, and profile.
 * Card chrome matches Swift `GraphFeedView.stateCard`.
 */
@Composable
fun AsyncBody(
    isLoading: Boolean,
    hasContent: Boolean,
    emptyTitle: String,
    emptyMessage: String,
    modifier: Modifier = Modifier,
    errorMessage: String? = null,
    loadingTitle: String = "Loading",
    loadingMessage: String = "",
    errorTitle: String = "Something went wrong",
    content: @Composable () -> Unit,
) {
    when {
        isLoading && !hasContent -> {
            AsyncStateCard(
                title = loadingTitle,
                message = loadingMessage,
                showsProgress = true,
                modifier = modifier,
            )
        }
        !hasContent && errorMessage != null -> {
            AsyncStateCard(
                title = errorTitle,
                message = errorMessage,
                showsProgress = false,
                modifier = modifier,
            )
        }
        !hasContent -> {
            AsyncStateCard(
                title = emptyTitle,
                message = emptyMessage,
                showsProgress = false,
                modifier = modifier,
            )
        }
        else -> content()
    }
}

/** Standalone loading / empty / error card (Swift `stateCard`). */
@Composable
fun AsyncStateCard(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    showsProgress: Boolean = false,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White.copy(alpha = 0.10f))
            .border(1.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(18.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (showsProgress) {
                CircularProgressIndicator(
                    modifier = Modifier
                        .padding(end = 10.dp)
                        .size(18.dp),
                    color = Color.White,
                    strokeWidth = 2.dp,
                )
            }
            Text(
                text = title,
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.weight(1f))
        }
        if (message.isNotBlank()) {
            Text(
                text = message,
                color = Color.White.copy(alpha = 0.72f),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun AsyncBodyLoadingPreview() {
    BubblerTheme {
        AsyncBody(
            isLoading = true,
            hasContent = false,
            emptyTitle = "No posts",
            emptyMessage = "Nothing here yet.",
            loadingTitle = "Loading graph feed",
            loadingMessage = "Pulling your initial session from Bubbler.",
            modifier = Modifier.padding(16.dp),
        ) {}
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun AsyncBodyEmptyPreview() {
    BubblerTheme {
        AsyncBody(
            isLoading = false,
            hasContent = false,
            emptyTitle = "No connected bubbles",
            emptyMessage = "Like, skip, or explore to keep walking the graph.",
            modifier = Modifier.padding(16.dp),
        ) {}
    }
}

package com.bubbler.android.ui.gallery

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.data.model.KnownTopics
import com.bubbler.android.ui.components.AsyncBody
import com.bubbler.android.ui.components.BubblerLogo
import com.bubbler.android.ui.components.PostCard
import com.bubbler.android.ui.components.PreferenceSliderRow
import com.bubbler.android.ui.components.PreferenceTopicsEditor
import com.bubbler.android.ui.components.StatusBanner
import com.bubbler.android.ui.components.TopicPicker
import com.bubbler.android.ui.components.samplePreviewPost

/**
 * Debug gallery for Phase 3 shared UI primitives.
 * Open via Compose Preview (`ComponentGalleryPreview`) or host in a debug route later.
 */
@Composable
fun ComponentGallery(modifier: Modifier = Modifier) {
    var selectedTopic by remember { mutableStateOf(KnownTopics.DEFAULT_TOPIC) }
    var diversity by remember { mutableFloatStateOf(0.4f) }
    var preferredTopics by remember { mutableStateOf(listOf("technology")) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF0D47A1),
                        Color(0xFF26C6DA),
                        Color(0xFF1565C0),
                        Color.Black.copy(alpha = 0.35f),
                    ),
                ),
            )
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        GallerySection(title = "BubblerLogo") {
            BubblerLogo(size = 160.dp)
        }

        GallerySection(title = "StatusBanner") {
            StatusBanner(
                message = "Preferred topic: Technology.",
                tint = Color.Cyan.copy(alpha = 0.85f),
            )
            StatusBanner(
                message = "Could not load the next bubble.",
                tint = Color.Red.copy(alpha = 0.8f),
            )
        }

        GallerySection(title = "AsyncBody") {
            AsyncBody(
                isLoading = true,
                hasContent = false,
                emptyTitle = "No posts",
                emptyMessage = "Nothing here yet.",
                loadingTitle = "Loading graph feed",
                loadingMessage = "Pulling your initial session from Bubbler.",
            ) {}
            AsyncBody(
                isLoading = false,
                hasContent = false,
                emptyTitle = "No connected bubbles",
                emptyMessage = "Like, skip, or explore to keep walking the graph.",
            ) {}
        }

        GallerySection(title = "TopicPicker") {
            TopicPicker(
                selectedTopic = selectedTopic,
                onTopicSelected = { selectedTopic = it },
            )
        }

        GallerySection(title = "PreferenceSliderRow") {
            PreferenceSliderRow(
                title = "Diversity",
                value = diversity,
                onValueChange = { diversity = it },
                tint = Color.Cyan,
            )
        }

        GallerySection(title = "PreferenceTopicsEditor") {
            PreferenceTopicsEditor(
                title = "Preferred topics",
                subtitle = "Boost posts in these bubbles.",
                icon = Icons.Filled.Star,
                iconColor = Color.Yellow,
                topics = preferredTopics,
                onTopicsChange = { preferredTopics = it },
            )
        }

        GallerySection(title = "PostCard") {
            PostCard(
                post = samplePreviewPost(),
                showsSkip = true,
                onSkip = {},
            )
            PostCard(
                post = samplePreviewPost(),
                showsSkip = true,
                isCompact = true,
                isTopicPreferred = true,
                onSkip = {},
            )
        }
    }
}

@Composable
private fun GallerySection(
    title: String,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = title.uppercase(),
            color = Color.White.copy(alpha = 0.55f),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.sp,
        )
        content()
    }
}

@Preview(showBackground = true, widthDp = 390, heightDp = 1200)
@Composable
fun ComponentGalleryPreview() {
    BubblerTheme {
        ComponentGallery()
    }
}

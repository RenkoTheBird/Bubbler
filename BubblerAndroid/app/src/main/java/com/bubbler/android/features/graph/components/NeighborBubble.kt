package com.bubbler.android.features.graph.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.data.model.GraphFeedNode
import com.bubbler.android.data.model.KnownTopics
import com.bubbler.android.data.model.Post
import com.bubbler.android.ui.theme.TopicStyle
import java.time.Instant

/**
 * Tappable neighbor choice bubble — mirrors Swift `GraphNeighborBubble`.
 */
@Composable
fun NeighborBubble(
    node: GraphFeedNode,
    size: Dp,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val topic = node.topicName ?: "topic"
    val color = TopicStyle.color(topic)
    val displayName = KnownTopics.displayName(topic)
    val accessibilityLabel = buildString {
        append(displayName)
        append(" bubble")
        if (node.isPreferredTopic) append(", preferred topic")
    }

    val density = LocalDensity.current
    val sizePx = with(density) { size.toPx() }
    val iconSize = size * 0.22f
    val labelSp = maxOf(10f, sizePx * 0.11f / density.density)
    val starSize = maxOf(10.dp, size * 0.13f)
    val badgePadding = size * 0.07f
    val badgeInset = size * 0.08f

    Box(
        modifier = modifier
            .size(size)
            .semantics { contentDescription = accessibilityLabel }
            .shadow(
                elevation = 14.dp,
                shape = CircleShape,
                ambientColor = color.copy(alpha = 0.45f),
                spotColor = color.copy(alpha = 0.45f),
            )
            .clip(CircleShape)
            .background(
                Brush.radialGradient(
                    colors = listOf(
                        color.copy(alpha = 0.95f),
                        color.copy(alpha = 0.55f),
                        color.copy(alpha = 0.25f),
                    ),
                    center = Offset(
                        x = sizePx * 0.28f,
                        y = sizePx * 0.28f,
                    ),
                    radius = sizePx * 0.7f,
                ),
            )
            .border(1.5.dp, Color.White.copy(alpha = 0.55f), CircleShape)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.padding(horizontal = 8.dp),
        ) {
            Icon(
                imageVector = TopicStyle.icon(topic),
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(iconSize),
            )
            Text(
                text = displayName,
                color = Color.White,
                fontSize = labelSp.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        if (node.isPreferredTopic) {
            Icon(
                imageVector = Icons.Filled.Star,
                contentDescription = null,
                tint = Color.Yellow.copy(alpha = 0.9f),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(badgeInset)
                    .size(starSize + badgePadding * 2)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.92f))
                    .padding(badgePadding),
            )
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun NeighborBubblePreview() {
    BubblerTheme {
        NeighborBubble(
            node = GraphFeedNode(
                post = Post(
                    id = "bubble-1",
                    userId = 1,
                    username = "neighbor",
                    content = "Sample neighbor post",
                    createdAt = Instant.now(),
                    topic = "technology",
                ),
                isPreferredTopic = true,
            ),
            size = 96.dp,
            onClick = {},
            modifier = Modifier.padding(24.dp),
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun NeighborBubblePlainPreview() {
    BubblerTheme {
        NeighborBubble(
            node = GraphFeedNode(
                post = Post(
                    id = "bubble-2",
                    userId = 2,
                    username = "walker",
                    content = "Another neighbor",
                    createdAt = Instant.now(),
                    topic = "sports",
                ),
            ),
            size = 96.dp,
            onClick = {},
            modifier = Modifier.padding(24.dp),
        )
    }
}

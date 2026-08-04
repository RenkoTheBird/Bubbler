package com.bubbler.android.features.graph.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.data.model.GraphFeedNode
import com.bubbler.android.data.model.Post
import java.time.Instant
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Polar layout of up to four neighbor bubbles — mirrors Swift `GraphFeedView.bubbleField`.
 */
@Composable
fun BubbleField(
    nodes: List<GraphFeedNode>,
    onBubbleClick: (GraphFeedNode) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val choices = nodes.take(4)

    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val fieldSize = min(maxWidth, maxHeight)
        val radius = fieldSize * 0.32f
        val bubbleSize = min(96.dp, fieldSize * 0.28f)
        val density = LocalDensity.current
        val radiusPx = with(density) { radius.toPx() }

        Box(modifier = Modifier.fillMaxSize()) {
            choices.forEachIndexed { index, node ->
                val angle = bubbleAngle(index = index, total = choices.size)
                val offsetX = (cos(angle) * radiusPx).roundToInt()
                val offsetY = (sin(angle) * radiusPx).roundToInt()

                NeighborBubble(
                    node = node,
                    size = bubbleSize,
                    onClick = { onBubbleClick(node) },
                    enabled = enabled,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .offset { IntOffset(offsetX, offsetY) },
                )
            }
        }
    }
}

/**
 * Even polar angles starting at 12 o'clock (negative Y), matching Swift `bubbleAngle`.
 */
fun bubbleAngle(index: Int, total: Int): Double {
    if (total <= 0) return 0.0
    val start = -PI / 2.0
    return start + (index.toDouble() / total.toDouble()) * (2.0 * PI)
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1, widthDp = 360, heightDp = 360)
@Composable
private fun BubbleFieldPreview() {
    BubblerTheme {
        BubbleField(
            nodes = listOf(
                sampleNeighbor("1", "technology", preferred = true),
                sampleNeighbor("2", "sports"),
                sampleNeighbor("3", "science"),
                sampleNeighbor("4", "entertainment"),
            ),
            onBubbleClick = {},
            modifier = Modifier.size(360.dp),
        )
    }
}

private fun sampleNeighbor(
    id: String,
    topic: String,
    preferred: Boolean = false,
): GraphFeedNode = GraphFeedNode(
    post = Post(
        id = id,
        userId = id.toIntOrNull() ?: 0,
        username = "neighbor$id",
        content = "Neighbor post $id",
        createdAt = Instant.now(),
        topic = topic,
    ),
    isPreferredTopic = preferred,
)

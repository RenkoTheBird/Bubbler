package com.bubbler.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.data.model.KnownTopics
import com.bubbler.android.ui.theme.TopicStyle

/** Topic chip grid for create-post — mirrors Swift `TopicPicker`. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TopicPicker(
    selectedTopic: String,
    onTopicSelected: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "Topic",
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = "Choose the bubble this post belongs to.",
            color = Color.White.copy(alpha = 0.65f),
            style = MaterialTheme.typography.bodySmall,
        )

        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            KnownTopics.ALL.forEach { topic ->
                TopicChip(
                    topic = topic,
                    selected = selectedTopic.equals(topic, ignoreCase = true),
                    onClick = { onTopicSelected(topic) },
                )
            }
        }
    }
}

@Composable
private fun TopicChip(
    topic: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val color = TopicStyle.color(topic)
    val shape = RoundedCornerShape(50)

    Row(
        modifier = Modifier
            .clip(shape)
            .background(
                if (selected) color.copy(alpha = 0.35f) else Color.White.copy(alpha = 0.1f),
            )
            .border(
                width = 1.dp,
                color = if (selected) color.copy(alpha = 0.7f) else Color.White.copy(alpha = 0.12f),
                shape = shape,
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = TopicStyle.icon(topic),
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp),
        )
        Text(
            text = KnownTopics.displayName(topic),
            color = Color.White,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun TopicPickerPreview() {
    BubblerTheme {
        TopicPicker(
            selectedTopic = "technology",
            onTopicSelected = {},
            modifier = Modifier.padding(16.dp),
        )
    }
}

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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.data.model.KnownTopics
import com.bubbler.android.data.model.TopicPreferenceList
import com.bubbler.android.ui.theme.TopicStyle

/**
 * Search-and-add topic list editor for preferred / blacklisted topics.
 * Mirrors Swift `PreferenceTopicsEditor`.
 */
@Composable
fun PreferenceTopicsEditor(
    title: String,
    subtitle: String,
    icon: ImageVector,
    iconColor: Color,
    topics: List<String>,
    onTopicsChange: (List<String>) -> Unit,
    modifier: Modifier = Modifier,
    conflictingTopics: List<String>? = null,
    onConflictingTopicsChange: ((List<String>) -> Unit)? = null,
) {
    var draft by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val matchingTopics = remember(draft, topics) {
        KnownTopics.matching(draft, excluding = topics)
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(22.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconColor,
                    modifier = Modifier.size(20.dp),
                )
                Text(
                    text = title,
                    color = Color.White,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            Text(
                text = subtitle,
                color = Color.White.copy(alpha = 0.65f),
                style = MaterialTheme.typography.bodySmall,
            )
        }

        TopicSearchField(
            draft = draft,
            onDraftChange = {
                draft = it
                errorMessage = null
            },
            iconColor = iconColor,
            onClear = {
                draft = ""
                errorMessage = null
            },
            onAdd = {
                addTopic(
                    draft = draft,
                    topics = topics,
                    onTopicsChange = onTopicsChange,
                    conflictingTopics = conflictingTopics,
                    onConflictingTopicsChange = onConflictingTopicsChange,
                    onDraftChange = { draft = it },
                    onError = { errorMessage = it },
                )
            },
        )

        errorMessage?.let { message ->
            Text(
                text = message,
                color = Color.Red.copy(alpha = 0.95f),
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        if (draft.trim().isNotEmpty()) {
            SuggestionResults(
                draft = draft.trim(),
                matchingTopics = matchingTopics,
                onSelect = { topic ->
                    selectTopic(
                        topic = topic,
                        topics = topics,
                        onTopicsChange = onTopicsChange,
                        conflictingTopics = conflictingTopics,
                        onConflictingTopicsChange = onConflictingTopicsChange,
                        onDraftChange = { draft = it },
                        onError = { errorMessage = it },
                    )
                },
            )
        }

        if (topics.isEmpty()) {
            Text(
                text = "No topics added yet.",
                color = Color.White.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            TopicChipGrid(
                topics = topics,
                onRemove = { topic ->
                    onTopicsChange(TopicPreferenceList.remove(topic, from = topics))
                },
            )
        }
    }
}

@Composable
private fun TopicSearchField(
    draft: String,
    onDraftChange: (String) -> Unit,
    iconColor: Color,
    onClear: () -> Unit,
    onAdd: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(14.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Search,
            contentDescription = null,
            tint = iconColor.copy(alpha = 0.9f),
            modifier = Modifier.size(18.dp),
        )
        BasicTextField(
            value = draft,
            onValueChange = onDraftChange,
            modifier = Modifier.weight(1f),
            singleLine = true,
            cursorBrush = SolidColor(Color.White),
            textStyle = MaterialTheme.typography.bodyMedium.copy(color = Color.White),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { onAdd() }),
            decorationBox = { inner ->
                if (draft.isEmpty()) {
                    Text(
                        text = "Search existing topics...",
                        color = Color.White.copy(alpha = 0.45f),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
                inner()
            },
        )
        if (draft.isNotEmpty()) {
            IconButton(
                onClick = onClear,
                modifier = Modifier.size(28.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.Cancel,
                    contentDescription = "Clear topic search",
                    tint = Color.White.copy(alpha = 0.55f),
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        TextButton(onClick = onAdd) {
            Text(
                text = "Add",
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun SuggestionResults(
    draft: String,
    matchingTopics: List<String>,
    onSelect: (String) -> Unit,
) {
    if (matchingTopics.isEmpty()) {
        Text(
            text = "No existing topics match \"$draft\".",
            color = Color.White.copy(alpha = 0.6f),
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.fillMaxWidth(),
        )
        return
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        matchingTopics.forEach { topic ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.White.copy(alpha = 0.1f))
                    .clickable { onSelect(topic) }
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(
                    imageVector = TopicStyle.icon(topic),
                    contentDescription = null,
                    tint = TopicStyle.color(topic),
                    modifier = Modifier.size(18.dp),
                )
                Text(
                    text = KnownTopics.displayName(topic),
                    color = Color.White,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = Icons.Filled.AddCircle,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.55f),
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TopicChipGrid(
    topics: List<String>,
    onRemove: (String) -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        topics.forEach { topic ->
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Color.White.copy(alpha = 0.1f))
                    .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(50))
                    .padding(horizontal = 12.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = KnownTopics.displayName(topic),
                    color = Color.White,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Icon(
                    imageVector = Icons.Filled.Cancel,
                    contentDescription = "Remove ${KnownTopics.displayName(topic)}",
                    tint = Color.White,
                    modifier = Modifier
                        .size(14.dp)
                        .clickable { onRemove(topic) },
                )
            }
        }
    }
}

private fun addTopic(
    draft: String,
    topics: List<String>,
    onTopicsChange: (List<String>) -> Unit,
    conflictingTopics: List<String>?,
    onConflictingTopicsChange: ((List<String>) -> Unit)?,
    onDraftChange: (String) -> Unit,
    onError: (String?) -> Unit,
) {
    val trimmed = draft.trim()
    if (trimmed.isEmpty()) {
        onError(null)
        return
    }
    val topic = KnownTopics.resolve(trimmed)
    if (topic == null) {
        onError("Unknown topic: \"$trimmed\". Choose one from the list of existing topics.")
        return
    }
    selectTopic(
        topic = topic,
        topics = topics,
        onTopicsChange = onTopicsChange,
        conflictingTopics = conflictingTopics,
        onConflictingTopicsChange = onConflictingTopicsChange,
        onDraftChange = onDraftChange,
        onError = onError,
    )
}

private fun selectTopic(
    topic: String,
    topics: List<String>,
    onTopicsChange: (List<String>) -> Unit,
    conflictingTopics: List<String>?,
    onConflictingTopicsChange: ((List<String>) -> Unit)?,
    onDraftChange: (String) -> Unit,
    onError: (String?) -> Unit,
) {
    val resolved = KnownTopics.resolve(topic)
    if (resolved == null) {
        onError("Unknown topic: \"$topic\". Choose one from the list of existing topics.")
        return
    }
    // Clear the other list first so preferred → blacklisted doesn't get
    // dropped by merge (preferred wins when both are present).
    if (conflictingTopics != null && onConflictingTopicsChange != null) {
        onConflictingTopicsChange(
            TopicPreferenceList.remove(resolved, from = conflictingTopics),
        )
    }
    onTopicsChange(TopicPreferenceList.add(resolved, to = topics))
    onDraftChange("")
    onError(null)
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun PreferenceTopicsEditorPreview() {
    BubblerTheme {
        PreferenceTopicsEditor(
            title = "Preferred topics",
            subtitle = "Boost posts in these bubbles.",
            icon = Icons.Filled.AddCircle,
            iconColor = Color.Yellow,
            topics = listOf("technology", "science"),
            onTopicsChange = {},
            modifier = Modifier.padding(16.dp),
        )
    }
}

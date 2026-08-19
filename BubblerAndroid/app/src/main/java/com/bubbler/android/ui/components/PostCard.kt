package com.bubbler.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.core.storage.LikedPostsStore
import com.bubbler.android.data.model.GraphInteractionPayload
import com.bubbler.android.data.model.GraphInteractionType
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository
import com.bubbler.android.features.report.ReportPostScreen
import com.bubbler.android.ui.theme.TopicStyle
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * Shared post card — mirrors Swift `PostCardView`.
 *
 * Repository wiring is optional so gallery / previews compile without a live API;
 * full interaction paths land with graph and feed screens.
 */
@Composable
fun PostCard(
    post: Post,
    modifier: Modifier = Modifier,
    showsSkip: Boolean = false,
    isCompact: Boolean = false,
    isTopicPreferred: Boolean = false,
    isTopicBlacklisted: Boolean = false,
    currentUserId: Int? = null,
    likedPostsStore: LikedPostsStore? = null,
    userRepository: UserRepository? = null,
    preferencesRepository: PreferencesRepository? = null,
    postRepository: PostRepository? = null,
    onUnauthorized: () -> Unit = {},
    onSuccessMessage: (String) -> Unit = {},
    onSkip: (() -> Unit)? = null,
    onLikeChanged: ((Boolean) -> Unit)? = null,
    onTopicPreferenceChanged: (() -> Unit)? = null,
    onDeleted: (() -> Unit)? = null,
    onEditClick: ((Post) -> Unit)? = null,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    val scope = rememberCoroutineScope()
    val likedIds by (
        likedPostsStore?.likedPostIds
            ?: remember { MutableStateFlow(emptySet()) }
        ).collectAsStateWithLifecycle(emptySet())

    var showDeleteConfirmation by remember { mutableStateOf(false) }
    var showOverflowMenu by remember { mutableStateOf(false) }
    var showReportForm by remember { mutableStateOf(false) }
    var isDeleting by remember { mutableStateOf(false) }
    var isTogglingLike by remember { mutableStateOf(false) }
    var isUpdatingTopicPreference by remember { mutableStateOf(false) }
    var preferredLocally by remember(post.id) { mutableStateOf<Boolean?>(null) }
    var blacklistedLocally by remember(post.id) { mutableStateOf<Boolean?>(null) }
    var actionError by remember(post.id) { mutableStateOf<String?>(null) }
    var appearedAt by remember(post.id) { mutableStateOf(Instant.now()) }

    LaunchedEffect(post.id) {
        appearedAt = Instant.now()
        preferredLocally = null
        blacklistedLocally = null
        actionError = null
    }
    LaunchedEffect(isTopicPreferred) { preferredLocally = null }
    LaunchedEffect(isTopicBlacklisted) { blacklistedLocally = null }

    val isOwned = currentUserId != null && currentUserId == post.userId
    val topicName = post.topic?.trim()?.takeIf { it.isNotEmpty() }
    val showsOverflowMenu = topicName != null || !isOwned
    val accentColor = topicName?.let { TopicStyle.color(it) } ?: Color.White
    val currentlyLiked = post.id in likedIds
    val currentlyPreferred = preferredLocally ?: isTopicPreferred
    val currentlyBlacklisted = blacklistedLocally ?: isTopicBlacklisted
    val corner = if (isCompact) 18.dp else 22.dp
    val cardPadding = if (isCompact) 12.dp else 16.dp

    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(
                elevation = 10.dp,
                shape = RoundedCornerShape(corner),
                ambientColor = accentColor.copy(alpha = 0.15f),
                spotColor = accentColor.copy(alpha = 0.15f),
            )
            .clip(RoundedCornerShape(corner))
            .background(Color.White.copy(alpha = 0.10f))
            .border(1.dp, accentColor.copy(alpha = 0.25f), RoundedCornerShape(corner))
            .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(corner))
            .padding(cardPadding),
        verticalArrangement = Arrangement.spacedBy(if (isCompact) 10.dp else 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.weight(1f),
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .shadow(6.dp, CircleShape, ambientColor = accentColor.copy(alpha = 0.8f))
                        .clip(CircleShape)
                        .background(accentColor),
                )
                Text(
                    text = (topicName ?: "POST").uppercase(),
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (currentlyPreferred) {
                    Icon(
                        imageVector = Icons.Filled.Star,
                        contentDescription = "Preferred topic",
                        tint = Color.Yellow.copy(alpha = 0.9f),
                        modifier = Modifier.size(12.dp),
                    )
                }
                if (currentlyBlacklisted) {
                    Icon(
                        imageVector = Icons.Filled.VisibilityOff,
                        contentDescription = "Blacklisted topic",
                        tint = Color(0xFFFF9800).copy(alpha = 0.9f),
                        modifier = Modifier.size(12.dp),
                    )
                }
            }

            Text(
                text = relativeTimeLabel(post.createdAt),
                color = Color.White.copy(alpha = 0.65f),
                style = MaterialTheme.typography.bodySmall,
            )

            if (showsOverflowMenu) {
                Box {
                    IconButton(
                        onClick = { showOverflowMenu = true },
                        enabled = !isUpdatingTopicPreference,
                        modifier = Modifier.size(36.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Filled.MoreHoriz,
                            contentDescription = "Post options",
                            tint = Color.White.copy(alpha = 0.85f),
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.12f))
                                .padding(6.dp),
                        )
                    }
                    DropdownMenu(
                        expanded = showOverflowMenu,
                        onDismissRequest = { showOverflowMenu = false },
                    ) {
                        if (topicName != null) {
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        if (currentlyPreferred) "Unprefer Topic" else "Prefer Topic",
                                    )
                                },
                                onClick = {
                                    showOverflowMenu = false
                                    scope.launch {
                                        togglePreferTopic(
                                            topic = topicName,
                                            currentlyPreferred = currentlyPreferred,
                                            preferencesRepository = preferencesRepository,
                                            onPreferred = { preferredLocally = it },
                                            onBlacklisted = { blacklistedLocally = it },
                                            onClearPreferred = { preferredLocally = null },
                                            onError = { actionError = it },
                                            onUnauthorized = onUnauthorized,
                                            onTopicPreferenceChanged = onTopicPreferenceChanged,
                                            setBusy = { isUpdatingTopicPreference = it },
                                        )
                                    }
                                },
                            )
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        if (currentlyBlacklisted) {
                                            "Unblacklist Topic"
                                        } else {
                                            "Blacklist Topic"
                                        },
                                    )
                                },
                                onClick = {
                                    showOverflowMenu = false
                                    scope.launch {
                                        toggleBlacklistTopic(
                                            topic = topicName,
                                            currentlyBlacklisted = currentlyBlacklisted,
                                            preferencesRepository = preferencesRepository,
                                            onBlacklisted = { blacklistedLocally = it },
                                            onPreferred = { preferredLocally = it },
                                            onClearBlacklisted = { blacklistedLocally = null },
                                            onError = { actionError = it },
                                            onUnauthorized = onUnauthorized,
                                            onTopicPreferenceChanged = onTopicPreferenceChanged,
                                            setBusy = { isUpdatingTopicPreference = it },
                                        )
                                    }
                                },
                            )
                        }
                        if (!isOwned) {
                            if (topicName != null) {
                                HorizontalDivider()
                            }
                            DropdownMenuItem(
                                text = { Text("Report Post") },
                                leadingIcon = {
                                    Icon(
                                        imageVector = Icons.Filled.Flag,
                                        contentDescription = null,
                                    )
                                },
                                onClick = {
                                    showOverflowMenu = false
                                    showReportForm = true
                                },
                            )
                        }
                    }
                }
            }
        }

        Text(
            text = post.content,
            color = Color.White,
            style = if (isCompact) {
                MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold)
            } else {
                MaterialTheme.typography.titleMedium
            },
            maxLines = if (isCompact) 3 else Int.MAX_VALUE,
            overflow = if (isCompact) TextOverflow.Ellipsis else TextOverflow.Clip,
        )

        val username = post.username?.takeIf { it.isNotEmpty() }
        val authorLabel = "Posted by ${post.authorLabel}"
        if (username != null && onAuthorClick != null) {
            Text(
                text = authorLabel,
                color = Color.White.copy(alpha = 0.7f),
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.clickable { onAuthorClick(username) },
            )
        } else {
            Text(
                text = authorLabel,
                color = Color.White.copy(alpha = 0.7f),
                style = MaterialTheme.typography.bodySmall,
            )
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(top = 2.dp),
        ) {
            ActionChip(
                label = if (currentlyLiked) "Liked" else "Like",
                highlighted = currentlyLiked,
                highlightColor = Color(0xFFE91E63),
                busy = isTogglingLike,
                enabled = !isTogglingLike && likedPostsStore != null && userRepository != null,
                leadingIcon = {
                    if (isTogglingLike) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(14.dp),
                            color = Color.White,
                            strokeWidth = 2.dp,
                        )
                    } else {
                        Icon(
                            imageVector = if (currentlyLiked) {
                                Icons.Filled.Favorite
                            } else {
                                Icons.Filled.FavoriteBorder
                            },
                            contentDescription = null,
                            tint = if (currentlyLiked) Color(0xFFE91E63) else Color.White,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                },
                onClick = {
                    scope.launch {
                        toggleLike(
                            postId = post.id,
                            currentlyLiked = currentlyLiked,
                            appearedAt = appearedAt,
                            likedPostsStore = likedPostsStore,
                            userRepository = userRepository,
                            onLikeChanged = onLikeChanged,
                            onError = { actionError = it },
                            onUnauthorized = onUnauthorized,
                            setBusy = { isTogglingLike = it },
                        )
                    }
                },
            )

            if (showsSkip && onSkip != null) {
                ActionChip(
                    label = "Skip",
                    highlighted = false,
                    highlightColor = Color.White,
                    busy = false,
                    enabled = true,
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(14.dp),
                        )
                    },
                    onClick = onSkip,
                )
            }

            Spacer(modifier = Modifier.weight(1f))
        }

        if (isOwned) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.padding(top = 4.dp),
            ) {
                if (onEditClick != null) {
                    OwnerActionButton(
                        label = "Edit",
                        containerColor = Color.White.copy(alpha = 0.14f),
                        busy = false,
                        enabled = true,
                        icon = Icons.Filled.Edit,
                        onClick = { onEditClick(post) },
                    )
                }
                OwnerActionButton(
                    label = if (isDeleting) "Deleting..." else "Delete",
                    containerColor = Color.Red.copy(alpha = 0.55f),
                    busy = isDeleting,
                    enabled = !isDeleting && postRepository != null,
                    icon = Icons.Filled.Delete,
                    onClick = { showDeleteConfirmation = true },
                )
                Spacer(modifier = Modifier.weight(1f))
            }
        }

        actionError?.let { error ->
            Text(
                text = error,
                color = Color.Red.copy(alpha = 0.9f),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }

    if (showDeleteConfirmation) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text("Delete this post?") },
            text = { Text("This permanently removes your post.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirmation = false
                        scope.launch {
                            deletePost(
                                postId = post.id,
                                postRepository = postRepository,
                                likedPostsStore = likedPostsStore,
                                onDeleted = onDeleted,
                                onSuccessMessage = onSuccessMessage,
                                onError = { actionError = it },
                                onUnauthorized = onUnauthorized,
                                setBusy = { isDeleting = it },
                            )
                        }
                    },
                ) {
                    Text("Delete Post", color = Color.Red)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmation = false }) {
                    Text("Cancel")
                }
            },
        )
    }

    if (showReportForm) {
        Dialog(
            onDismissRequest = { showReportForm = false },
            properties = DialogProperties(
                dismissOnBackPress = true,
                dismissOnClickOutside = false,
                usePlatformDefaultWidth = false,
            ),
        ) {
            ReportPostScreen(
                post = post,
                onBack = { showReportForm = false },
                onSubmitted = { showReportForm = false },
                onUnauthorized = onUnauthorized,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
private fun ActionChip(
    label: String,
    highlighted: Boolean,
    highlightColor: Color,
    busy: Boolean,
    enabled: Boolean,
    leadingIcon: @Composable () -> Unit,
    onClick: () -> Unit,
) {
    val fill = if (highlighted) highlightColor.copy(alpha = 0.22f) else Color.White.copy(alpha = 0.12f)
    val stroke = if (highlighted) highlightColor.copy(alpha = 0.45f) else Color.White.copy(alpha = 0.16f)
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(fill)
            .border(1.dp, stroke, RoundedCornerShape(50))
            .clickable(enabled = enabled && !busy, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        leadingIcon()
        Text(
            text = label,
            color = if (highlighted) highlightColor else Color.White,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun OwnerActionButton(
    label: String,
    containerColor: Color,
    busy: Boolean,
    enabled: Boolean,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(containerColor)
            .clickable(enabled = enabled && !busy, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (busy) {
            CircularProgressIndicator(
                modifier = Modifier.size(14.dp),
                color = Color.White,
                strokeWidth = 2.dp,
            )
        } else {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(14.dp),
            )
        }
        Text(
            text = label,
            color = Color.White,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

private suspend fun toggleLike(
    postId: String,
    currentlyLiked: Boolean,
    appearedAt: Instant,
    likedPostsStore: LikedPostsStore?,
    userRepository: UserRepository?,
    onLikeChanged: ((Boolean) -> Unit)?,
    onError: (String?) -> Unit,
    onUnauthorized: () -> Unit,
    setBusy: (Boolean) -> Unit,
) {
    if (likedPostsStore == null || userRepository == null) return
    setBusy(true)
    onError(null)
    try {
        if (currentlyLiked) {
            userRepository.deleteLike(postId)
            likedPostsStore.setLiked(postId, liked = false)
            onLikeChanged?.invoke(false)
        } else {
            val viewTime = Duration.between(appearedAt, Instant.now()).seconds
                .toDouble()
                .coerceAtLeast(0.0)
            userRepository.recordInteraction(
                GraphInteractionPayload(
                    postId = postId,
                    type = GraphInteractionType.LIKE,
                    viewTime = viewTime,
                ),
            )
            likedPostsStore.setLiked(postId, liked = true)
            onLikeChanged?.invoke(true)
        }
    } catch (e: ApiException.Unauthorized) {
        onUnauthorized()
        onError(e.message)
    } catch (e: Exception) {
        onError(e.message ?: "Something went wrong.")
    } finally {
        setBusy(false)
    }
}

private suspend fun togglePreferTopic(
    topic: String,
    currentlyPreferred: Boolean,
    preferencesRepository: PreferencesRepository?,
    onPreferred: (Boolean) -> Unit,
    onBlacklisted: (Boolean) -> Unit,
    onClearPreferred: () -> Unit,
    onError: (String?) -> Unit,
    onUnauthorized: () -> Unit,
    onTopicPreferenceChanged: (() -> Unit)?,
    setBusy: (Boolean) -> Unit,
) {
    if (preferencesRepository == null) {
        onError("Preferences are unavailable.")
        return
    }
    setBusy(true)
    onError(null)
    try {
        var preferences = preferencesRepository.getPreferences().sanitized()
        preferences = if (currentlyPreferred) {
            onPreferred(false)
            preferences.unpreferTopic(topic)
        } else {
            onPreferred(true)
            onBlacklisted(false)
            preferences.preferTopic(topic)
        }
        preferencesRepository.updatePreferences(preferences.sanitized().updatePayload)
        onTopicPreferenceChanged?.invoke()
    } catch (e: ApiException.Unauthorized) {
        onUnauthorized()
        onClearPreferred()
        onError(e.message)
    } catch (e: Exception) {
        onClearPreferred()
        onError(e.message ?: "Something went wrong.")
    } finally {
        setBusy(false)
    }
}

private suspend fun toggleBlacklistTopic(
    topic: String,
    currentlyBlacklisted: Boolean,
    preferencesRepository: PreferencesRepository?,
    onBlacklisted: (Boolean) -> Unit,
    onPreferred: (Boolean) -> Unit,
    onClearBlacklisted: () -> Unit,
    onError: (String?) -> Unit,
    onUnauthorized: () -> Unit,
    onTopicPreferenceChanged: (() -> Unit)?,
    setBusy: (Boolean) -> Unit,
) {
    if (preferencesRepository == null) {
        onError("Preferences are unavailable.")
        return
    }
    setBusy(true)
    onError(null)
    try {
        var preferences = preferencesRepository.getPreferences().sanitized()
        preferences = if (currentlyBlacklisted) {
            onBlacklisted(false)
            preferences.unblacklistTopic(topic)
        } else {
            onBlacklisted(true)
            onPreferred(false)
            preferences.blacklistTopic(topic)
        }
        preferencesRepository.updatePreferences(preferences.sanitized().updatePayload)
        onTopicPreferenceChanged?.invoke()
    } catch (e: ApiException.Unauthorized) {
        onUnauthorized()
        onClearBlacklisted()
        onError(e.message)
    } catch (e: Exception) {
        onClearBlacklisted()
        onError(e.message ?: "Something went wrong.")
    } finally {
        setBusy(false)
    }
}

private suspend fun deletePost(
    postId: String,
    postRepository: PostRepository?,
    likedPostsStore: LikedPostsStore?,
    onDeleted: (() -> Unit)?,
    onSuccessMessage: (String) -> Unit,
    onError: (String?) -> Unit,
    onUnauthorized: () -> Unit,
    setBusy: (Boolean) -> Unit,
) {
    if (postRepository == null) return
    setBusy(true)
    onError(null)
    try {
        postRepository.deletePost(postId)
        likedPostsStore?.setLiked(postId, liked = false)
        onSuccessMessage("Post deleted.")
        onDeleted?.invoke()
    } catch (e: ApiException.Unauthorized) {
        onUnauthorized()
        onError(e.message)
    } catch (e: Exception) {
        onError(e.message ?: "Something went wrong.")
    } finally {
        setBusy(false)
    }
}

private fun relativeTimeLabel(instant: Instant, now: Instant = Instant.now()): String {
    val seconds = Duration.between(instant, now).seconds.coerceAtLeast(0)
    return when {
        seconds < 60 -> "${seconds}s ago"
        seconds < 3_600 -> "${TimeUnit.SECONDS.toMinutes(seconds)}m ago"
        seconds < 86_400 -> "${TimeUnit.SECONDS.toHours(seconds)}h ago"
        else -> "${TimeUnit.SECONDS.toDays(seconds)}d ago"
    }
}

fun samplePreviewPost(): Post = Post(
    id = "preview-post",
    userId = 0,
    username = "preview",
    content = "A sample bubble post for the card preview.",
    createdAt = Instant.now().minusSeconds(2_700),
    topic = "technology",
    embedding = null,
)

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun PostCardPreview() {
    BubblerTheme {
        PostCard(
            post = samplePreviewPost(),
            showsSkip = true,
            onSkip = {},
            modifier = Modifier.padding(16.dp),
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF0D47A1)
@Composable
private fun PostCardCompactPreview() {
    BubblerTheme {
        PostCard(
            post = samplePreviewPost(),
            showsSkip = true,
            isCompact = true,
            isTopicPreferred = true,
            onSkip = {},
            modifier = Modifier.padding(16.dp),
        )
    }
}

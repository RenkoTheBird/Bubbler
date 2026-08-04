package com.bubbler.android.features.feed

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.storage.LikedPostsStore
import com.bubbler.android.data.model.KnownTopics
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.FeedRepository
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository
import com.bubbler.android.ui.components.AsyncStateCard
import com.bubbler.android.ui.components.BubblerLogo
import com.bubbler.android.ui.components.PostCard
import com.bubbler.android.ui.theme.TopicStyle

/**
 * Ranked discovery feed — mirrors Swift `FeedView`.
 *
 * Topic strip is All + [KnownTopics]; selecting a chip reloads `/feed/me?q=…`
 * and prioritizes matching posts client-side.
 *
 * [refreshNonce] bumps after create/edit so the list reloads from the server.
 */
@Composable
fun RankedFeedScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    modifier: Modifier = Modifier,
    refreshNonce: Int = 0,
    onEditPost: ((Post) -> Unit)? = null,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    val context = LocalContext.current
    val tokenStore = remember(context) { TokenStore(context.applicationContext) }
    val feedRepository = remember(apiClient, tokenStore) { FeedRepository(apiClient, tokenStore) }
    val preferencesRepository = remember(apiClient, tokenStore) {
        PreferencesRepository(apiClient, tokenStore)
    }
    val userRepository = remember(apiClient, tokenStore) { UserRepository(apiClient, tokenStore) }
    val postRepository = remember(apiClient, tokenStore) { PostRepository(apiClient, tokenStore) }
    val likedPostsStore = remember(userRepository) { LikedPostsStore(userRepository) }

    val viewModel: RankedFeedViewModel = viewModel(
        factory = RankedFeedViewModelFactory(
            authSession = authSession,
            feedRepository = feedRepository,
        ),
    )

    RankedFeedScreenContent(
        authSession = authSession,
        viewModel = viewModel,
        likedPostsStore = likedPostsStore,
        preferencesRepository = preferencesRepository,
        userRepository = userRepository,
        postRepository = postRepository,
        modifier = modifier,
        refreshNonce = refreshNonce,
        onEditPost = onEditPost,
        onAuthorClick = onAuthorClick,
    )
}

@Composable
fun RankedFeedScreenContent(
    authSession: AuthSession,
    viewModel: RankedFeedViewModel,
    likedPostsStore: LikedPostsStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    modifier: Modifier = Modifier,
    refreshNonce: Int = 0,
    onEditPost: ((Post) -> Unit)? = null,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    val accessToken by authSession.accessToken.collectAsStateWithLifecycle()
    val userId by authSession.userId.collectAsStateWithLifecycle()
    val selectedTopic by viewModel.selectedTopic.collectAsStateWithLifecycle()
    val posts by viewModel.posts.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    LaunchedEffect(accessToken) {
        if (accessToken != null) {
            likedPostsStore.refresh()
            viewModel.loadFeed()
        } else {
            likedPostsStore.clear()
        }
    }

    LaunchedEffect(refreshNonce) {
        if (refreshNonce > 0 && accessToken != null) {
            viewModel.loadFeed()
        }
    }

    val feedTopics: List<String?> = remember { listOf(null) + KnownTopics.ALL }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF1565C0).copy(alpha = 0.9f),
                        Color(0xFF00BCD4).copy(alpha = 0.55f),
                        Color(0xFF303F9F).copy(alpha = 0.9f),
                        Color.Black.copy(alpha = 0.3f),
                    ),
                ),
            ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            FeedHeader(modifier = Modifier.padding(top = 8.dp))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                feedTopics.forEach { topic ->
                    TopicChip(
                        topic = topic,
                        selectedTopic = selectedTopic,
                        enabled = !isLoading,
                        onClick = { viewModel.selectTopic(topic) },
                    )
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                when {
                    isLoading && posts.isEmpty() -> {
                        AsyncStateCard(
                            title = "Loading your feed",
                            message = "Pulling the latest posts from Bubbler.",
                            showsProgress = true,
                        )
                    }
                    errorMessage != null -> {
                        AsyncStateCard(
                            title = "Couldn't load the feed",
                            message = errorMessage.orEmpty(),
                        )
                    }
                    posts.isEmpty() -> {
                        AsyncStateCard(
                            title = "No posts yet",
                            message = if (selectedTopic == null) {
                                "Posts from the database will show up here after the feed has data."
                            } else {
                                "No posts matched this topic yet. Try another bubble."
                            },
                        )
                    }
                    else -> {
                        posts.forEach { post ->
                            PostCard(
                                post = post,
                                currentUserId = userId,
                                likedPostsStore = likedPostsStore,
                                userRepository = userRepository,
                                preferencesRepository = preferencesRepository,
                                postRepository = postRepository,
                                onUnauthorized = { authSession.signOut() },
                                onSuccessMessage = { authSession.showSuccessMessage(it) },
                                onDeleted = { viewModel.removePost(id = post.id) },
                                onEditClick = onEditPost,
                                onAuthorClick = onAuthorClick,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FeedHeader(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        BubblerLogo(
            size = 55.dp,
            modifier = Modifier
                .padding(bottom = 16.dp)
                .shadow(8.dp, ambientColor = Color(0xFF2196F3).copy(alpha = 0.2f)),
        )
        Text(
            text = "BUBBLER",
            color = Color.White,
            fontSize = 34.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 2.sp,
            textAlign = TextAlign.Center,
        )
        Text(
            text = "your interest field is active",
            color = Color.White.copy(alpha = 0.75f),
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun TopicChip(
    topic: String?,
    selectedTopic: String?,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val label: String
    val icon: ImageVector
    val color: Color
    val isActive: Boolean

    if (topic != null) {
        label = KnownTopics.displayName(topic)
        icon = TopicStyle.icon(topic)
        color = TopicStyle.color(topic)
        isActive = selectedTopic.equals(topic, ignoreCase = true)
    } else {
        label = "All"
        icon = Icons.Filled.AutoAwesome
        color = Color.Cyan
        isActive = selectedTopic == null
    }

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (isActive) color.copy(alpha = 0.35f) else Color.White.copy(alpha = 0.10f))
            .border(
                width = 1.dp,
                color = if (isActive) color.copy(alpha = 0.6f) else Color.White.copy(alpha = 0.15f),
                shape = RoundedCornerShape(50),
            )
            .then(
                if (isActive) {
                    Modifier.shadow(10.dp, spotColor = color.copy(alpha = 0.4f))
                } else {
                    Modifier
                },
            )
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(14.dp),
        )
        Text(
            text = label,
            color = Color.White,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Preview(showBackground = true, widthDp = 390, heightDp = 780)
@Composable
private fun RankedFeedLoadingPreview() {
    BubblerTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF1565C0),
                            Color(0xFF00BCD4),
                            Color(0xFF303F9F),
                        ),
                    ),
                )
                .padding(16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Spacer(modifier = Modifier.height(40.dp))
                AsyncStateCard(
                    title = "Loading your feed",
                    message = "Pulling the latest posts from Bubbler.",
                    showsProgress = true,
                )
            }
        }
    }
}

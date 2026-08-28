package com.bubbler.android.features.graph

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CallSplit
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.storage.FeedPreferencesStore
import com.bubbler.android.data.model.GraphFeedNode
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.FeedRepository
import com.bubbler.android.data.repository.GraphRepository
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository
import com.bubbler.android.features.graph.components.BubbleField
import com.bubbler.android.ui.components.AsyncStateCard
import com.bubbler.android.ui.components.PostCard
import com.bubbler.android.ui.components.StatusBanner
import kotlinx.coroutines.launch

/**
 * Graph walk UI — mirrors Swift `GraphFeedView`.
 *
 * [onSignOut] is optional debug chrome; production sign-out lives on Settings.
 * [refreshNonce] bumps after create/edit so the session reloads.
 */
@Composable
fun GraphFeedScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    modifier: Modifier = Modifier,
    refreshNonce: Int = 0,
    onSignOut: (() -> Unit)? = null,
    onEditPost: ((Post) -> Unit)? = null,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    val context = LocalContext.current
    val tokenStore = remember(context) { TokenStore(context.applicationContext) }
    val feedRepository = remember(apiClient, tokenStore) { FeedRepository(apiClient, tokenStore) }
    val graphRepository = remember(apiClient, tokenStore) { GraphRepository(apiClient, tokenStore) }
    val preferencesRepository = remember(apiClient, tokenStore) {
        PreferencesRepository(apiClient, tokenStore)
    }
    val userRepository = remember(apiClient, tokenStore) { UserRepository(apiClient, tokenStore) }
    val postRepository = remember(apiClient, tokenStore) { PostRepository(apiClient, tokenStore) }
    val feedPreferencesStore = remember(userRepository) { FeedPreferencesStore(userRepository) }

    val viewModel: GraphFeedViewModel = viewModel(
        factory = GraphFeedViewModelFactory(
            authSession = authSession,
            feedRepository = feedRepository,
            graphRepository = graphRepository,
            preferencesRepository = preferencesRepository,
            userRepository = userRepository,
            postRepository = postRepository,
        ),
    )

    GraphFeedScreenContent(
        authSession = authSession,
        viewModel = viewModel,
        feedPreferencesStore = feedPreferencesStore,
        preferencesRepository = preferencesRepository,
        userRepository = userRepository,
        postRepository = postRepository,
        modifier = modifier,
        refreshNonce = refreshNonce,
        onSignOut = onSignOut,
        onEditPost = onEditPost,
        onAuthorClick = onAuthorClick,
    )
}

@Composable
fun GraphFeedScreenContent(
    authSession: AuthSession,
    viewModel: GraphFeedViewModel,
    feedPreferencesStore: FeedPreferencesStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    modifier: Modifier = Modifier,
    refreshNonce: Int = 0,
    onSignOut: (() -> Unit)? = null,
    onEditPost: ((Post) -> Unit)? = null,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    val accessToken by authSession.accessToken.collectAsStateWithLifecycle()
    val userId by authSession.userId.collectAsStateWithLifecycle()
    val currentNode by viewModel.currentNode.collectAsStateWithLifecycle()
    val nextChoices by viewModel.nextChoices.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isSubmitting by viewModel.isSubmitting.collectAsStateWithLifecycle()
    val statusMessage by viewModel.statusMessage.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    var previewedChoiceId by remember { mutableStateOf<String?>(null) }
    val previewedChoice = nextChoices.firstOrNull { it.id == previewedChoiceId }
    val scope = rememberCoroutineScope()

    LaunchedEffect(accessToken) {
        if (accessToken != null) {
            feedPreferencesStore.refresh()
            viewModel.load()
        } else {
            feedPreferencesStore.clear()
        }
    }

    LaunchedEffect(refreshNonce) {
        if (refreshNonce > 0 && accessToken != null) {
            viewModel.load()
        }
    }

    LaunchedEffect(currentNode?.id) {
        previewedChoiceId = null
    }

    LaunchedEffect(nextChoices.map { it.id }) {
        val previewId = previewedChoiceId ?: return@LaunchedEffect
        if (nextChoices.none { it.id == previewId }) {
            previewedChoiceId = null
        }
    }

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
                .padding(horizontal = 16.dp)
                .padding(bottom = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TopChrome(
                isBusy = isLoading || isSubmitting,
                onExplore = {
                    previewedChoiceId = null
                    scope.launch { viewModel.refreshSession() }
                },
                onSignOut = onSignOut,
            )

            statusMessage?.let { message ->
                StatusBanner(
                    message = message,
                    tint = Color.Cyan.copy(alpha = 0.85f),
                )
            }

            errorMessage?.let { message ->
                StatusBanner(
                    message = message,
                    tint = Color.Red.copy(alpha = 0.8f),
                )
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                MiddleSection(
                    isLoading = isLoading,
                    hasCurrentPost = viewModel.hasCurrentPost,
                    previewedChoiceId = previewedChoiceId,
                    previewedChoice = previewedChoice,
                    currentNode = currentNode,
                    nextChoices = nextChoices,
                    isSubmitting = isSubmitting,
                    authSession = authSession,
                    viewModel = viewModel,
                    feedPreferencesStore = feedPreferencesStore,
                    preferencesRepository = preferencesRepository,
                    userRepository = userRepository,
                    postRepository = postRepository,
                    currentUserId = userId,
                    onPreview = { previewedChoiceId = it },
                    onClearPreview = { previewedChoiceId = null },
                )
            }

            currentNode?.let { node ->
                StickyCurrentPost(
                    node = node,
                    currentUserId = userId,
                    feedPreferencesStore = feedPreferencesStore,
                    preferencesRepository = preferencesRepository,
                    userRepository = userRepository,
                    postRepository = postRepository,
                    onUnauthorized = { authSession.signOut() },
                    onSuccessMessage = { authSession.showSuccessMessage(it) },
                    onSkip = {
                        previewedChoiceId = null
                        scope.launch { viewModel.skipCurrentPost() }
                    },
                    onTopicPreferenceChanged = {
                        scope.launch { viewModel.syncTopicPreferences() }
                    },
                    onDeleted = {
                        scope.launch { viewModel.handleCurrentPostDeleted() }
                    },
                    onEditPost = onEditPost,
                    onAuthorClick = onAuthorClick,
                )
            }
        }
    }
}

@Composable
private fun TopChrome(
    isBusy: Boolean,
    onExplore: () -> Unit,
    onSignOut: (() -> Unit)?,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isBusy) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                color = Color.White,
                strokeWidth = 2.dp,
            )
        }

        if (onSignOut != null) {
            Text(
                text = "Sign out",
                color = Color.White.copy(alpha = 0.75f),
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier
                    .padding(start = if (isBusy) 12.dp else 0.dp)
                    .clip(RoundedCornerShape(50))
                    .clickable(onClick = onSignOut)
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .background(Color.White.copy(alpha = 0.14f))
                .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(50))
                .semantics { contentDescription = "Explore Other Bubbles" }
                .clickable(enabled = !isBusy, onClick = onExplore)
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.CallSplit,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(14.dp),
            )
            Text(
                text = "Explore",
                color = Color.White,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun MiddleSection(
    isLoading: Boolean,
    hasCurrentPost: Boolean,
    previewedChoiceId: String?,
    previewedChoice: GraphFeedNode?,
    currentNode: GraphFeedNode?,
    nextChoices: List<GraphFeedNode>,
    isSubmitting: Boolean,
    authSession: AuthSession,
    viewModel: GraphFeedViewModel,
    feedPreferencesStore: FeedPreferencesStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    currentUserId: Int?,
    onPreview: (String) -> Unit,
    onClearPreview: () -> Unit,
) {
    val scope = rememberCoroutineScope()

    when {
        isLoading && !hasCurrentPost -> {
            AsyncStateCard(
                title = "Loading graph feed",
                message = "Pulling your initial session from Bubbler.",
                showsProgress = true,
            )
        }
        previewedChoiceId != null -> {
            if (previewedChoice != null) {
                PreviewSection(
                    node = previewedChoice,
                    isSubmitting = isSubmitting,
                    currentUserId = currentUserId,
                    feedPreferencesStore = feedPreferencesStore,
                    preferencesRepository = preferencesRepository,
                    userRepository = userRepository,
                    postRepository = postRepository,
                    onUnauthorized = { authSession.signOut() },
                    onSuccessMessage = { authSession.showSuccessMessage(it) },
                    onBack = onClearPreview,
                    onSelect = {
                        scope.launch {
                            viewModel.choose(previewedChoice)
                            onClearPreview()
                        }
                    },
                    onTopicPreferenceChanged = {
                        scope.launch { viewModel.syncTopicPreferences() }
                    },
                )
            } else {
                AsyncStateCard(
                    title = "Loading preview",
                    message = "Refreshing this bubble.",
                    showsProgress = true,
                )
            }
        }
        currentNode == null -> {
            AsyncStateCard(
                title = "No session loaded",
                message = "Generate a new graph session to start exploring connected posts.",
            )
        }
        nextChoices.isEmpty() -> {
            AsyncStateCard(
                title = "No connected bubbles",
                message = "Like, skip, or explore to keep walking the graph.",
            )
        }
        else -> {
            BubbleField(
                nodes = nextChoices,
                onBubbleClick = { node -> onPreview(node.id) },
                enabled = !isSubmitting,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
private fun PreviewSection(
    node: GraphFeedNode,
    isSubmitting: Boolean,
    currentUserId: Int?,
    feedPreferencesStore: FeedPreferencesStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    onUnauthorized: () -> Unit,
    onSuccessMessage: (String) -> Unit,
    onBack: () -> Unit,
    onSelect: () -> Unit,
    onTopicPreferenceChanged: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            ChromePill(
                label = "Back",
                icon = {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp),
                    )
                },
                background = Color.White.copy(alpha = 0.12f),
                contentColor = Color.White,
                onClick = onBack,
            )

            Spacer(modifier = Modifier.weight(1f))

            ChromePill(
                label = "Select",
                icon = {
                    Icon(
                        imageVector = Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = Color.Black,
                        modifier = Modifier.size(16.dp),
                    )
                },
                background = Color.White,
                contentColor = Color.Black,
                enabled = !isSubmitting,
                onClick = onSelect,
            )
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
        ) {
            PostCard(
                post = node.post,
                showsSkip = false,
                isCompact = false,
                isTopicPreferred = node.isPreferredTopic,
                isTopicBlacklisted = node.isBlacklistedTopic,
                currentUserId = currentUserId,
                feedPreferencesStore = feedPreferencesStore,
                userRepository = userRepository,
                preferencesRepository = preferencesRepository,
                postRepository = postRepository,
                onUnauthorized = onUnauthorized,
                onSuccessMessage = onSuccessMessage,
                onTopicPreferenceChanged = onTopicPreferenceChanged,
            )
        }
    }
}

@Composable
private fun StickyCurrentPost(
    node: GraphFeedNode,
    currentUserId: Int?,
    feedPreferencesStore: FeedPreferencesStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    onUnauthorized: () -> Unit,
    onSuccessMessage: (String) -> Unit,
    onSkip: () -> Unit,
    onTopicPreferenceChanged: () -> Unit,
    onDeleted: () -> Unit,
    onEditPost: ((Post) -> Unit)? = null,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "CURRENT",
            color = Color.White.copy(alpha = 0.55f),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.sp,
        )

        PostCard(
            post = node.post,
            showsSkip = true,
            isCompact = true,
            isTopicPreferred = node.isPreferredTopic,
            isTopicBlacklisted = node.isBlacklistedTopic,
            currentUserId = currentUserId,
            feedPreferencesStore = feedPreferencesStore,
            userRepository = userRepository,
            preferencesRepository = preferencesRepository,
            postRepository = postRepository,
            onUnauthorized = onUnauthorized,
            onSuccessMessage = onSuccessMessage,
            onSkip = onSkip,
            onTopicPreferenceChanged = onTopicPreferenceChanged,
            onDeleted = onDeleted,
            onEditClick = onEditPost,
            onAuthorClick = onAuthorClick,
        )
    }
}

@Composable
private fun ChromePill(
    label: String,
    icon: @Composable () -> Unit,
    background: Color,
    contentColor: Color,
    onClick: () -> Unit,
    enabled: Boolean = true,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(background)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        icon()
        Text(
            text = label,
            color = contentColor,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Preview(showBackground = true, widthDp = 390, heightDp = 780)
@Composable
private fun GraphFeedScreenLoadingPreview() {
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
            AsyncStateCard(
                title = "Loading graph feed",
                message = "Pulling your initial session from Bubbler.",
                showsProgress = true,
            )
        }
    }
}

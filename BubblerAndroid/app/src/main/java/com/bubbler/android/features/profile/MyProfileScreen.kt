package com.bubbler.android.features.profile

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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Timeline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.storage.FeedPreferencesStore
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.BlocksRepository
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.UserRepository
import com.bubbler.android.features.post.CreatePostScreen
import com.bubbler.android.ui.components.PostCard
import kotlinx.coroutines.launch

/**
 * Own profile tab root — mirrors Swift `ProfileView()` with `username == nil`.
 */
@Composable
fun MyProfileScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onOpenBubbleTrail: () -> Unit,
    modifier: Modifier = Modifier,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    ProfileScreen(
        authSession = authSession,
        apiClient = apiClient,
        targetUsername = null,
        onOpenBubbleTrail = onOpenBubbleTrail,
        onAuthorClick = onAuthorClick,
        onBack = null,
        modifier = modifier,
    )
}

/**
 * Shared profile loader used by [MyProfileScreen] and [UserProfileScreen].
 */
@Composable
fun ProfileScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    targetUsername: String?,
    modifier: Modifier = Modifier,
    onOpenBubbleTrail: (() -> Unit)? = null,
    onAuthorClick: ((String) -> Unit)? = null,
    onBack: (() -> Unit)? = null,
) {
    val context = LocalContext.current
    val tokenStore = remember(context) { TokenStore(context.applicationContext) }
    val userRepository = remember(apiClient, tokenStore) { UserRepository(apiClient, tokenStore) }
    val blocksRepository = remember(apiClient, tokenStore) { BlocksRepository(apiClient, tokenStore) }
    val preferencesRepository = remember(apiClient, tokenStore) {
        PreferencesRepository(apiClient, tokenStore)
    }
    val postRepository = remember(apiClient, tokenStore) { PostRepository(apiClient, tokenStore) }
    val feedPreferencesStore = remember(userRepository) { FeedPreferencesStore(userRepository) }

    val viewModelKey = targetUsername?.trim()?.takeIf { it.isNotEmpty() } ?: "me"
    val viewModel: ProfileViewModel = viewModel(
        key = viewModelKey,
        factory = ProfileViewModelFactory(
            authSession = authSession,
            userRepository = userRepository,
            blocksRepository = blocksRepository,
            targetUsername = targetUsername,
        ),
    )

    var editingPost by remember { mutableStateOf<Post?>(null) }
    val postBeingEdited = editingPost

    if (postBeingEdited != null) {
        CreatePostScreen(
            authSession = authSession,
            apiClient = apiClient,
            post = postBeingEdited,
            onBack = { editingPost = null },
            onSuccess = { content ->
                viewModel.updatePostContent(id = postBeingEdited.id, content = content)
                editingPost = null
            },
            modifier = modifier,
        )
    } else {
        ProfileScreenContent(
            authSession = authSession,
            viewModel = viewModel,
            feedPreferencesStore = feedPreferencesStore,
            preferencesRepository = preferencesRepository,
            userRepository = userRepository,
            postRepository = postRepository,
            onOpenBubbleTrail = onOpenBubbleTrail,
            onAuthorClick = onAuthorClick,
            onEditPost = { editingPost = it },
            onBack = onBack,
            modifier = modifier,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreenContent(
    authSession: AuthSession,
    viewModel: ProfileViewModel,
    feedPreferencesStore: FeedPreferencesStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    onEditPost: (Post) -> Unit,
    modifier: Modifier = Modifier,
    onOpenBubbleTrail: (() -> Unit)? = null,
    onAuthorClick: ((String) -> Unit)? = null,
    onBack: (() -> Unit)? = null,
) {
    val accessToken by authSession.accessToken.collectAsStateWithLifecycle()
    val sessionUserId by authSession.userId.collectAsStateWithLifecycle()
    val successMessage by authSession.successMessage.collectAsStateWithLifecycle()
    val posts by viewModel.posts.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isBlocked by viewModel.isBlocked.collectAsStateWithLifecycle()
    val isUpdatingBlock by viewModel.isUpdatingBlock.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    val username by viewModel.username.collectAsStateWithLifecycle()

    val scope = rememberCoroutineScope()
    var isRefreshing by remember { mutableStateOf(false) }
    var showBlockConfirmation by remember { mutableStateOf(false) }

    val showsBlockControls = viewModel.canManageBlock(sessionUserId)

    LaunchedEffect(accessToken) {
        if (accessToken != null) {
            feedPreferencesStore.refresh()
            viewModel.refreshPosts()
        } else {
            feedPreferencesStore.clear()
        }
    }

    LaunchedEffect(successMessage) {
        val message = successMessage ?: return@LaunchedEffect
        if (!viewModel.isOwnProfile) return@LaunchedEffect
        val lower = message.lowercase()
        if (lower.contains("post published") || lower.contains("post updated")) {
            viewModel.refreshPosts()
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            if (onBack != null || showsBlockControls) {
                TopAppBar(
                    title = { },
                    navigationIcon = {
                        if (onBack != null) {
                            IconButton(
                                onClick = onBack,
                                modifier = Modifier.semantics { contentDescription = "Back" },
                            ) {
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                    contentDescription = null,
                                )
                            }
                        }
                    },
                    actions = {
                        if (showsBlockControls) {
                            when {
                                isUpdatingBlock -> {
                                    CircularProgressIndicator(
                                        modifier = Modifier
                                            .padding(end = 16.dp)
                                            .size(20.dp),
                                        color = Color.White,
                                        strokeWidth = 2.dp,
                                    )
                                }
                                isBlocked -> {
                                    TextButton(onClick = { viewModel.unblockUser() }) {
                                        Text(
                                            text = "Unblock",
                                            color = Color.White,
                                            fontWeight = FontWeight.SemiBold,
                                        )
                                    }
                                }
                                else -> {
                                    TextButton(onClick = { showBlockConfirmation = true }) {
                                        Text(
                                            text = "Block",
                                            color = Color.White,
                                            fontWeight = FontWeight.SemiBold,
                                        )
                                    }
                                }
                            }
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent,
                        navigationIconContentColor = Color.White,
                        actionIconContentColor = Color.White,
                    ),
                )
            }
        },
        containerColor = Color.Transparent,
    ) { innerPadding ->
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = {
                scope.launch {
                    isRefreshing = true
                    viewModel.refreshPosts()
                    isRefreshing = false
                }
            },
            modifier = Modifier
                .fillMaxSize()
                .background(profileGradient())
                .padding(innerPadding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                Spacer(modifier = Modifier.height(20.dp))

                ActiveBubbleChip(
                    label = viewModel.activeBubbleLabel(posts = posts, isLoading = isLoading),
                )

                ProfileAvatar()

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = viewModel.displayUsername(
                            username = username,
                            isLoading = isLoading,
                        ),
                        color = Color.White,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Black,
                    )
                    Text(
                        text = viewModel.profileSubtitle(isBlocked = isBlocked),
                        color = Color.White.copy(alpha = 0.85f),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    if (errorMessage != null) {
                        Text(
                            text = errorMessage.orEmpty(),
                            color = Color.White.copy(alpha = 0.75f),
                            style = MaterialTheme.typography.bodySmall,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(horizontal = 24.dp),
                        )
                    }
                }

                if (viewModel.isOwnProfile && onOpenBubbleTrail != null) {
                    BubbleTrailLink(
                        onClick = onOpenBubbleTrail,
                        modifier = Modifier.padding(horizontal = 20.dp),
                    )
                }

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Text(
                        text = if (viewModel.isOwnProfile) "Your Posts" else "Posts",
                        color = Color.White,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 20.dp),
                    )

                    when {
                        posts.isEmpty() -> {
                            Text(
                                text = viewModel.emptyPostsMessage(isLoading = isLoading),
                                color = Color.White.copy(alpha = 0.75f),
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.padding(horizontal = 20.dp),
                            )
                        }
                        else -> {
                            Column(
                                modifier = Modifier.padding(horizontal = 20.dp),
                                verticalArrangement = Arrangement.spacedBy(18.dp),
                            ) {
                                posts.forEach { post ->
                                    PostCard(
                                        post = post,
                                        isCompact = true,
                                        currentUserId = sessionUserId,
                                        feedPreferencesStore = feedPreferencesStore,
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
    }

    if (showBlockConfirmation) {
        AlertDialog(
            onDismissRequest = { showBlockConfirmation = false },
            title = {
                Text(
                    "Block ${viewModel.displayUsername(username = username, isLoading = isLoading)}?",
                )
            },
            text = {
                Text(
                    "Their posts won’t appear in your feed or search. You can unblock them later in Settings.",
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showBlockConfirmation = false
                        viewModel.blockUser()
                    },
                ) {
                    Text("Block")
                }
            },
            dismissButton = {
                TextButton(onClick = { showBlockConfirmation = false }) {
                    Text("Cancel")
                }
            },
        )
    }
}

@Composable
private fun ActiveBubbleChip(label: String) {
    Text(
        text = label,
        color = Color.White.copy(alpha = 0.9f),
        style = MaterialTheme.typography.labelLarge,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
            .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 8.dp),
    )
}

@Composable
private fun ProfileAvatar() {
    Box(contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .size(170.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.06f)),
        )
        Box(
            modifier = Modifier
                .size(135.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.10f))
                .border(1.dp, Color.White.copy(alpha = 0.25f), CircleShape),
        )
        Box(
            modifier = Modifier
                .size(110.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Person,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(46.dp),
            )
        }
    }
}

@Composable
private fun BubbleTrailLink(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(16.dp))
            .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Timeline,
            contentDescription = null,
            tint = Color.White,
        )
        Text(
            text = "Bubble Trail",
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f),
        )
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.55f),
        )
    }
}

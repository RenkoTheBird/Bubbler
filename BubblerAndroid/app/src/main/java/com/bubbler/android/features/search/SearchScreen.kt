package com.bubbler.android.features.search

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
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
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.data.repository.PreferencesRepository
import com.bubbler.android.data.repository.SearchRepository
import com.bubbler.android.data.repository.UserRepository
import com.bubbler.android.features.post.CreatePostScreen
import com.bubbler.android.features.profile.UserProfileScreen
import com.bubbler.android.ui.components.AsyncStateCard
import com.bubbler.android.ui.components.PostCard
import kotlinx.coroutines.launch

private const val SEARCH_PREFS_NAME = "bubbler_search"

/**
 * Hybrid search — mirrors Swift `SearchView`.
 *
 * Exact + related sections, recent searches, and PostCard edit/delete hooks.
 * Author taps open [UserProfileScreen] as an overlay on this tab.
 */
@Composable
fun SearchScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val tokenStore = remember(context) { TokenStore(context.applicationContext) }
    val searchRepository = remember(apiClient, tokenStore) {
        SearchRepository(apiClient, tokenStore)
    }
    val preferencesRepository = remember(apiClient, tokenStore) {
        PreferencesRepository(apiClient, tokenStore)
    }
    val userRepository = remember(apiClient, tokenStore) { UserRepository(apiClient, tokenStore) }
    val postRepository = remember(apiClient, tokenStore) { PostRepository(apiClient, tokenStore) }
    val feedPreferencesStore = remember(userRepository) { FeedPreferencesStore(userRepository) }
    val prefs = remember(context) {
        context.applicationContext.getSharedPreferences(SEARCH_PREFS_NAME, Context.MODE_PRIVATE)
    }

    val viewModel: SearchViewModel = viewModel(
        factory = SearchViewModelFactory(
            authSession = authSession,
            searchRepository = searchRepository,
            prefs = prefs,
        ),
    )

    var editingPost by remember { mutableStateOf<Post?>(null) }
    var viewingUsername by remember { mutableStateOf<String?>(null) }
    val postBeingEdited = editingPost
    val profileUsername = viewingUsername

    when {
        profileUsername != null -> {
            UserProfileScreen(
                username = profileUsername,
                authSession = authSession,
                apiClient = apiClient,
                onBack = { viewingUsername = null },
                onAuthorClick = { next ->
                    if (!next.equals(profileUsername, ignoreCase = true)) {
                        viewingUsername = next
                    }
                },
                modifier = modifier,
            )
        }
        postBeingEdited != null -> {
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
        }
        else -> {
            SearchScreenContent(
                authSession = authSession,
                viewModel = viewModel,
                feedPreferencesStore = feedPreferencesStore,
                preferencesRepository = preferencesRepository,
                userRepository = userRepository,
                postRepository = postRepository,
                modifier = modifier,
                onEditPost = { editingPost = it },
                onAuthorClick = { viewingUsername = it },
            )
        }
    }
}

@Composable
fun SearchScreenContent(
    authSession: AuthSession,
    viewModel: SearchViewModel,
    feedPreferencesStore: FeedPreferencesStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    onEditPost: (Post) -> Unit,
    modifier: Modifier = Modifier,
    onAuthorClick: ((String) -> Unit)? = null,
) {
    val accessToken by authSession.accessToken.collectAsStateWithLifecycle()
    val userId by authSession.userId.collectAsStateWithLifecycle()
    val searchText by viewModel.searchText.collectAsStateWithLifecycle()
    val exactMatches by viewModel.exactMatches.collectAsStateWithLifecycle()
    val related by viewModel.related.collectAsStateWithLifecycle()
    val recentSearches by viewModel.recentSearches.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    val hasSearched by viewModel.hasSearched.collectAsStateWithLifecycle()
    val lastQuery by viewModel.lastQuery.collectAsStateWithLifecycle()
    val keyboardController = LocalSoftwareKeyboardController.current
    val scope = rememberCoroutineScope()

    LaunchedEffect(userId) {
        viewModel.loadRecentSearches(userId)
    }

    LaunchedEffect(accessToken) {
        if (accessToken != null) {
            feedPreferencesStore.refresh()
        } else {
            feedPreferencesStore.clear()
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
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp)
                .padding(top = 20.dp, bottom = 80.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Search",
                    color = Color.White,
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Black,
                )
                Text(
                    text = "find your next bubble",
                    color = Color.White.copy(alpha = 0.8f),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                )
            }

            SearchField(
                value = searchText,
                enabled = !isLoading,
                onValueChange = viewModel::updateSearchText,
                onSearch = {
                    keyboardController?.hide()
                    scope.launch { viewModel.search(recordRecent = true) }
                },
                onClear = viewModel::clearSearch,
            )

            if (recentSearches.isNotEmpty()) {
                RecentSearchesSection(
                    searches = recentSearches,
                    enabled = !isLoading,
                    onSelect = viewModel::runRecentSearch,
                )
            }

            ResultsSection(
                isLoading = isLoading,
                errorMessage = errorMessage,
                hasSearched = hasSearched,
                lastQuery = lastQuery,
                exactMatches = exactMatches,
                related = related,
                userId = userId,
                feedPreferencesStore = feedPreferencesStore,
                preferencesRepository = preferencesRepository,
                userRepository = userRepository,
                postRepository = postRepository,
                onUnauthorized = { authSession.signOut() },
                onSuccessMessage = { authSession.showSuccessMessage(it) },
                onDeleted = viewModel::removePost,
                onEditPost = onEditPost,
                onAuthorClick = onAuthorClick,
            )
        }
    }
}

@Composable
private fun SearchField(
    value: String,
    enabled: Boolean,
    onValueChange: (String) -> Unit,
    onSearch: () -> Unit,
    onClear: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.16f), RoundedCornerShape(18.dp))
            .border(1.dp, Color.White.copy(alpha = 0.25f), RoundedCornerShape(18.dp))
            .padding(horizontal = 12.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(
            onClick = onSearch,
            enabled = enabled,
            modifier = Modifier.semantics { contentDescription = "Search" },
        ) {
            Icon(
                imageVector = Icons.Filled.Search,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.75f),
            )
        }

        Box(modifier = Modifier.weight(1f)) {
            if (value.isEmpty()) {
                Text(
                    text = "Search for a bubble...",
                    color = Color.White.copy(alpha = 0.55f),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                enabled = enabled,
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = Color.White),
                cursorBrush = SolidColor(Color.White),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { onSearch() }),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        if (value.isNotEmpty()) {
            IconButton(
                onClick = onClear,
                modifier = Modifier.semantics { contentDescription = "Clear search" },
            ) {
                Icon(
                    imageVector = Icons.Filled.Cancel,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.55f),
                )
            }
        }
    }
}

@Composable
private fun RecentSearchesSection(
    searches: List<String>,
    enabled: Boolean,
    onSelect: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            text = "Recent Searches",
            color = Color.White,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
        )

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            searches.forEach { search ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.White.copy(alpha = 0.13f), RoundedCornerShape(16.dp))
                        .clickable(enabled = enabled) { onSelect(search) }
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.History,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.75f),
                    )
                    Text(
                        text = search,
                        color = Color.White,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.weight(1f),
                    )
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.55f),
                    )
                }
            }
        }
    }
}

@Composable
private fun ResultsSection(
    isLoading: Boolean,
    errorMessage: String?,
    hasSearched: Boolean,
    lastQuery: String,
    exactMatches: List<Post>,
    related: List<Post>,
    userId: Int?,
    feedPreferencesStore: FeedPreferencesStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    onUnauthorized: () -> Unit,
    onSuccessMessage: (String) -> Unit,
    onDeleted: (String) -> Unit,
    onEditPost: (Post) -> Unit,
    onAuthorClick: ((String) -> Unit)?,
) {
    val posts = exactMatches + related

    when {
        isLoading && posts.isEmpty() -> {
            AsyncStateCard(
                title = "Searching",
                message = "Looking for bubbles that match your query.",
                showsProgress = true,
            )
        }
        errorMessage != null -> {
            AsyncStateCard(
                title = "Couldn't search",
                message = errorMessage,
            )
        }
        hasSearched -> {
            if (posts.isEmpty()) {
                AsyncStateCard(
                    title = "Nothing matched \"$lastQuery\"",
                    message = "Try different words, a topic name, or a username.",
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
                    if (exactMatches.isNotEmpty()) {
                        PostSection(
                            title = "Exact matches",
                            subtitle = "Keyword, topic, or username hits",
                            posts = exactMatches,
                            userId = userId,
                            feedPreferencesStore = feedPreferencesStore,
                            preferencesRepository = preferencesRepository,
                            userRepository = userRepository,
                            postRepository = postRepository,
                            onUnauthorized = onUnauthorized,
                            onSuccessMessage = onSuccessMessage,
                            onDeleted = onDeleted,
                            onEditPost = onEditPost,
                            onAuthorClick = onAuthorClick,
                        )
                    }
                    if (related.isNotEmpty()) {
                        PostSection(
                            title = "Related",
                            subtitle = "Similar meaning and nearby bubbles",
                            posts = related,
                            userId = userId,
                            feedPreferencesStore = feedPreferencesStore,
                            preferencesRepository = preferencesRepository,
                            userRepository = userRepository,
                            postRepository = postRepository,
                            onUnauthorized = onUnauthorized,
                            onSuccessMessage = onSuccessMessage,
                            onDeleted = onDeleted,
                            onEditPost = onEditPost,
                            onAuthorClick = onAuthorClick,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PostSection(
    title: String,
    subtitle: String,
    posts: List<Post>,
    userId: Int?,
    feedPreferencesStore: FeedPreferencesStore,
    preferencesRepository: PreferencesRepository,
    userRepository: UserRepository,
    postRepository: PostRepository,
    onUnauthorized: () -> Unit,
    onSuccessMessage: (String) -> Unit,
    onDeleted: (String) -> Unit,
    onEditPost: (Post) -> Unit,
    onAuthorClick: ((String) -> Unit)?,
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = title,
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = subtitle,
                color = Color.White.copy(alpha = 0.65f),
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium,
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            posts.forEach { post ->
                PostCard(
                    post = post,
                    currentUserId = userId,
                    feedPreferencesStore = feedPreferencesStore,
                    userRepository = userRepository,
                    preferencesRepository = preferencesRepository,
                    postRepository = postRepository,
                    onUnauthorized = onUnauthorized,
                    onSuccessMessage = onSuccessMessage,
                    onDeleted = { onDeleted(post.id) },
                    onEditClick = onEditPost,
                    onAuthorClick = onAuthorClick,
                )
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun SearchFieldPreview() {
    BubblerTheme {
        Box(
            modifier = Modifier
                .background(Color(0xFF1565C0))
                .padding(16.dp),
        ) {
            SearchField(
                value = "technology",
                enabled = true,
                onValueChange = {},
                onSearch = {},
                onClear = {},
            )
        }
    }
}

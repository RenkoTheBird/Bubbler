package com.bubbler.android.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Hexagon
import androidx.compose.material3.Icon
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.bubbler.android.app.navigation.Routes
import com.bubbler.android.app.theme.BubblerBlue
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.model.Post
import com.bubbler.android.features.feed.RankedFeedScreen
import com.bubbler.android.features.graph.GraphFeedScreen
import com.bubbler.android.features.post.CreatePostScreen
import com.bubbler.android.features.profile.UserProfileScreen
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

private enum class FeedMode {
    Graph,
    Ranked,
}

/** Matches the top stop of the graph / ranked feed gradient. */
private val FeedChromeBlue = Color(0xFF1565C0).copy(alpha = 0.9f)

/**
 * Feed tab shell — mirrors the Feed `NavigationStack` inside Swift `MainTabView`.
 *
 * Owns the graph ↔ ranked toggle, Create / Edit Post entry, and public profiles.
 */
@Composable
fun FeedTabScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    modifier: Modifier = Modifier,
    navController: NavHostController = rememberNavController(),
) {
    var feedModeName by rememberSaveable { mutableStateOf(FeedMode.Graph.name) }
    val feedMode = FeedMode.entries.firstOrNull { it.name == feedModeName } ?: FeedMode.Graph
    var editingPost by remember { mutableStateOf<Post?>(null) }
    var feedRefreshNonce by remember { mutableIntStateOf(0) }

    fun openCreatePost(post: Post? = null) {
        editingPost = post
        navController.navigate(Routes.CREATE_POST)
    }

    fun closeCreatePost(refresh: Boolean) {
        editingPost = null
        if (refresh) {
            feedRefreshNonce += 1
        }
        navController.popBackStack()
    }

    fun openUserProfile(username: String) {
        navController.navigate(Routes.userProfile(username))
    }

    NavHost(
        navController = navController,
        startDestination = Routes.FEED_HOME,
        modifier = modifier.fillMaxSize(),
    ) {
        composable(Routes.FEED_HOME) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(FeedChromeBlue),
            ) {
                FeedModeFabs(
                    feedMode = feedMode,
                    onToggleMode = {
                        feedModeName = if (feedMode == FeedMode.Graph) {
                            FeedMode.Ranked.name
                        } else {
                            FeedMode.Graph.name
                        }
                    },
                    onCreatePost = { openCreatePost() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp),
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                ) {
                    when (feedMode) {
                        FeedMode.Graph -> GraphFeedScreen(
                            authSession = authSession,
                            apiClient = apiClient,
                            refreshNonce = feedRefreshNonce,
                            onEditPost = { openCreatePost(it) },
                            onAuthorClick = ::openUserProfile,
                        )
                        FeedMode.Ranked -> RankedFeedScreen(
                            authSession = authSession,
                            apiClient = apiClient,
                            refreshNonce = feedRefreshNonce,
                            onEditPost = { openCreatePost(it) },
                            onAuthorClick = ::openUserProfile,
                        )
                    }
                }
            }
        }
        composable(Routes.CREATE_POST) {
            CreatePostScreen(
                authSession = authSession,
                apiClient = apiClient,
                post = editingPost,
                onBack = { closeCreatePost(refresh = false) },
                onSuccess = { closeCreatePost(refresh = true) },
            )
        }
        composable(
            route = Routes.USER_PROFILE,
            arguments = listOf(navArgument("username") { type = NavType.StringType }),
        ) { entry ->
            val encoded = entry.arguments?.getString("username").orEmpty()
            val username = URLDecoder.decode(encoded, StandardCharsets.UTF_8.name())
            UserProfileScreen(
                username = username,
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
                onAuthorClick = { next ->
                    if (!next.equals(username, ignoreCase = true)) {
                        navController.navigate(Routes.userProfile(next))
                    }
                },
            )
        }
    }
}

@Composable
private fun FeedModeFabs(
    feedMode: FeedMode,
    onToggleMode: () -> Unit,
    onCreatePost: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val toggleDescription =
        if (feedMode == FeedMode.Graph) "Switch to Feed" else "Switch to Graph"
    val toggleIcon =
        if (feedMode == FeedMode.Graph) Icons.AutoMirrored.Filled.List else Icons.Filled.Hexagon

    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SmallFloatingActionButton(
            onClick = onToggleMode,
            containerColor = Color.White,
            contentColor = BubblerBlue,
            modifier = Modifier.semantics { contentDescription = toggleDescription },
        ) {
            Icon(
                imageVector = toggleIcon,
                contentDescription = null,
            )
        }
        SmallFloatingActionButton(
            onClick = onCreatePost,
            containerColor = Color.White,
            contentColor = BubblerBlue,
            modifier = Modifier.semantics { contentDescription = "Create Post" },
        ) {
            Icon(
                imageVector = Icons.Filled.Edit,
                contentDescription = null,
            )
        }
    }
}

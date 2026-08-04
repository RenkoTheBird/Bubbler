package com.bubbler.android.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.bubbler.android.app.theme.BubblerBlue
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.features.profile.ProfileTabScreen
import com.bubbler.android.features.search.SearchScreen
import com.bubbler.android.features.settings.SettingsTabScreen

private enum class MainTab(
    val label: String,
    val icon: ImageVector,
) {
    Feed("Feed", Icons.Filled.Home),
    Search("Search", Icons.Filled.Search),
    Profile("Profile", Icons.Filled.Person),
    Settings("Settings", Icons.Filled.Settings),
}

/**
 * Main tab bar — mirrors Swift `MainTabView`.
 *
 * Feed, Search, Profile, and Settings stay composed while hidden so graph
 * session / search results / profile / settings stack state survive tab
 * switches the same way SwiftUI `TabView` keeps tab roots alive.
 */
@Composable
fun MainTabScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    modifier: Modifier = Modifier,
) {
    var selectedTab by rememberSaveable { mutableStateOf(MainTab.Feed.name) }
    val currentTab = MainTab.entries.firstOrNull { it.name == selectedTab } ?: MainTab.Feed

    Scaffold(
        modifier = modifier.fillMaxSize(),
        bottomBar = {
            Surface(
                color = Color.White,
                shadowElevation = 6.dp,
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .windowInsetsPadding(WindowInsets.navigationBars)
                        .height(48.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    MainTab.entries.forEach { tab ->
                        val selected = currentTab == tab
                        IconButton(
                            onClick = { selectedTab = tab.name },
                            modifier = Modifier.semantics {
                                contentDescription = tab.label
                            },
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(40.dp)
                                    .clip(CircleShape)
                                    .background(
                                        if (selected) {
                                            BubblerBlue.copy(alpha = 0.12f)
                                        } else {
                                            Color.Transparent
                                        },
                                    ),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    imageVector = tab.icon,
                                    contentDescription = null,
                                    tint = if (selected) {
                                        BubblerBlue
                                    } else {
                                        BubblerBlue.copy(alpha = 0.45f)
                                    },
                                )
                            }
                        }
                    }
                }
            }
        },
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            Box(
                modifier = if (currentTab == MainTab.Feed) {
                    Modifier.fillMaxSize()
                } else {
                    Modifier.size(0.dp)
                },
            ) {
                FeedTabScreen(
                    authSession = authSession,
                    apiClient = apiClient,
                )
            }

            Box(
                modifier = if (currentTab == MainTab.Search) {
                    Modifier.fillMaxSize()
                } else {
                    Modifier.size(0.dp)
                },
            ) {
                SearchScreen(
                    authSession = authSession,
                    apiClient = apiClient,
                )
            }

            Box(
                modifier = if (currentTab == MainTab.Profile) {
                    Modifier.fillMaxSize()
                } else {
                    Modifier.size(0.dp)
                },
            ) {
                ProfileTabScreen(
                    authSession = authSession,
                    apiClient = apiClient,
                )
            }

            Box(
                modifier = if (currentTab == MainTab.Settings) {
                    Modifier.fillMaxSize()
                } else {
                    Modifier.size(0.dp)
                },
            ) {
                SettingsTabScreen(
                    authSession = authSession,
                    apiClient = apiClient,
                )
            }
        }
    }
}

@Composable
internal fun ComingSoonPane(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center,
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun ComingSoonPanePreview() {
    BubblerTheme {
        ComingSoonPane(
            title = "Settings",
            message = "Account, preferences, and blocks arrive in Phase 7.",
        )
    }
}

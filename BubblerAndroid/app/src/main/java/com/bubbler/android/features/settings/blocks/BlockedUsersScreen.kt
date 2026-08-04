package com.bubbler.android.features.settings.blocks

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.model.BlockedUser
import com.bubbler.android.data.repository.BlocksRepository
import com.bubbler.android.features.settings.SettingsGradient
import com.bubbler.android.features.settings.SettingsHeader
import com.bubbler.android.features.settings.SettingsLoadingCard
import com.bubbler.android.features.settings.SettingsMessageCard
import com.bubbler.android.features.settings.SettingsSectionCard
import kotlinx.coroutines.launch

/**
 * Blocked users management — mirrors Swift `BlockedView`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BlockedUsersScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val factory = remember(authSession, apiClient, context) {
        BlocksViewModelFactory(
            authSession = authSession,
            blocksRepository = BlocksRepository(
                apiClient = apiClient,
                tokenStore = TokenStore(context.applicationContext),
            ),
        )
    }
    val viewModel: BlocksViewModel = viewModel(factory = factory)
    val scope = rememberCoroutineScope()

    val blockedUsers by viewModel.blockedUsers.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isUpdating by viewModel.isUpdating.collectAsStateWithLifecycle()
    val errorTitle by viewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    var userPendingUnblock by remember { mutableStateOf<BlockedUser?>(null) }
    var isRefreshing by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.loadBlockedUsersAwait()
    }

    userPendingUnblock?.let { user ->
        AlertDialog(
            onDismissRequest = { userPendingUnblock = null },
            title = { Text("Unblock @${user.username}?") },
            text = {
                Text("They will be able to appear in your feed again once unblocked.")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val target = user
                        userPendingUnblock = null
                        viewModel.unblock(target)
                    },
                ) {
                    Text("Unblock")
                }
            },
            dismissButton = {
                TextButton(onClick = { userPendingUnblock = null }) {
                    Text("Cancel")
                }
            },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Blocked") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White,
                ),
            )
        },
        containerColor = Color.Transparent,
    ) { innerPadding ->
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = {
                scope.launch {
                    isRefreshing = true
                    viewModel.loadBlockedUsersAwait(force = true)
                    isRefreshing = false
                }
            },
            modifier = Modifier
                .fillMaxSize()
                .background(SettingsGradient)
                .padding(innerPadding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp, bottom = 40.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                SettingsHeader(
                    title = "Blocked Users",
                    subtitle = "People you block won’t appear in your feed or search results.",
                )

                errorMessage?.let { message ->
                    SettingsMessageCard(
                        title = errorTitle,
                        message = message,
                        tint = Color.Red,
                    )
                }

                when {
                    isLoading && blockedUsers.isEmpty() -> {
                        SettingsLoadingCard(message = "Fetching your blocked users.")
                    }
                    blockedUsers.isEmpty() -> {
                        SettingsSectionCard(title = "No blocked users") {
                            Text(
                                text = "When you block someone from their profile, they’ll show up here so you can unblock them anytime.",
                                color = Color.White.copy(alpha = 0.85f),
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                    else -> {
                        SettingsSectionCard(
                            title = "Blocked",
                            subtitle = if (blockedUsers.size == 1) {
                                "1 person"
                            } else {
                                "${blockedUsers.size} people"
                            },
                        ) {
                            blockedUsers.forEachIndexed { index, user ->
                                BlockedUserRow(
                                    user = user,
                                    enabled = !isUpdating,
                                    onUnblock = { userPendingUnblock = user },
                                )
                                if (index < blockedUsers.lastIndex) {
                                    HorizontalDivider(
                                        color = Color.White.copy(alpha = 0.12f),
                                        modifier = Modifier.padding(vertical = 2.dp),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BlockedUserRow(
    user: BlockedUser,
    enabled: Boolean,
    onUnblock: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.16f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.Person,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.75f),
                modifier = Modifier.size(18.dp),
            )
        }
        Text(
            text = "@${user.username}",
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f),
        )
        TextButton(
            onClick = onUnblock,
            enabled = enabled,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White.copy(alpha = if (enabled) 0.16f else 0.08f)),
        ) {
            Text(
                text = "Unblock",
                color = Color.White.copy(alpha = if (enabled) 1f else 0.55f),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

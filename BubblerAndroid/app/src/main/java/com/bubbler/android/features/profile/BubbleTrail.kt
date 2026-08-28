package com.bubbler.android.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.repository.UserRepository

/**
 * Signed-in user's interaction history — mirrors Swift `BubbleTrailView`.
 */
@Composable
fun BubbleTrailScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val tokenStore = remember(context) { TokenStore(context.applicationContext) }
    val userRepository = remember(apiClient, tokenStore) { UserRepository(apiClient, tokenStore) }
    val viewModel: BubbleTrailViewModel = viewModel(
        factory = BubbleTrailViewModelFactory(
            authSession = authSession,
            userRepository = userRepository,
        ),
    )

    BubbleTrailScreenContent(
        viewModel = viewModel,
        onBack = onBack,
        modifier = modifier,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BubbleTrailScreenContent(
    viewModel: BubbleTrailViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val interactions by viewModel.interactions.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.load()
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text("Bubble Trail") },
                navigationIcon = {
                    IconButton(
                        onClick = onBack,
                        modifier = Modifier.semantics { contentDescription = "Back" },
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = null,
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
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(profileGradient())
                .padding(innerPadding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(top = 12.dp, bottom = 40.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    text = "Your recent interactions across Bubbler.",
                    color = Color.White.copy(alpha = 0.75f),
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )

                when {
                    isLoading && interactions.isEmpty() -> {
                        TrailRow(text = "Loading your bubble trail…")
                    }
                    errorMessage != null -> {
                        TrailRow(text = errorMessage.orEmpty())
                    }
                    interactions.isEmpty() -> {
                        TrailRow(
                            text = "Your bubble trail will appear here once you start interacting with posts.",
                        )
                    }
                    else -> {
                        interactions.forEach { interaction ->
                            TrailRow(text = interaction.trailSummary)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TrailRow(text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .background(Color.White.copy(alpha = 0.10f), RoundedCornerShape(18.dp))
            .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(18.dp))
            .padding(horizontal = 14.dp, vertical = 14.dp),
    ) {
        Text(
            text = text,
            color = Color.White.copy(alpha = 0.9f),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Normal,
        )
        Spacer(modifier = Modifier.weight(1f))
    }
}

internal fun profileGradient(): Brush =
    Brush.linearGradient(
        colors = listOf(
            Color(0xFF1565C0).copy(alpha = 0.9f),
            Color(0xFF00BCD4).copy(alpha = 0.6f),
            Color(0xFF303F9F).copy(alpha = 0.8f),
            Color(0xFF1565C0),
        ),
    )

@Preview(showBackground = true)
@Composable
private fun TrailRowPreview() {
    BubblerTheme {
        Box(
            modifier = Modifier
                .background(profileGradient())
                .padding(vertical = 16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                TrailRow(text = "Much more for a Technology post")
                TrailRow(text = "Skipped a post")
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    }
}

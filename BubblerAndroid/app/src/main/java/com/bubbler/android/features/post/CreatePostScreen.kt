package com.bubbler.android.features.post

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
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
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.repository.PostRepository
import com.bubbler.android.ui.components.TopicPicker
import com.bubbler.android.ui.theme.TopicStyle

/**
 * Create / edit post — mirrors Swift `CreatePostView`.
 *
 * [post] non-null enters edit mode (content + topic sync on save).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreatePostScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    modifier: Modifier = Modifier,
    post: Post? = null,
    onBack: () -> Unit = {},
    onSuccess: (String) -> Unit = {},
) {
    val context = LocalContext.current
    val tokenStore = remember(context) { TokenStore(context.applicationContext) }
    val postRepository = remember(apiClient, tokenStore) { PostRepository(apiClient, tokenStore) }

    val viewModel: CreatePostViewModel = viewModel(
        key = post?.id ?: "create_post_new",
        factory = CreatePostViewModelFactory(
            authSession = authSession,
            postRepository = postRepository,
            post = post,
        ),
    )

    CreatePostScreenContent(
        viewModel = viewModel,
        modifier = modifier,
        onBack = onBack,
        onSuccess = onSuccess,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreatePostScreenContent(
    viewModel: CreatePostViewModel,
    modifier: Modifier = Modifier,
    onBack: () -> Unit = {},
    onSuccess: (String) -> Unit = {},
) {
    val content by viewModel.content.collectAsStateWithLifecycle()
    val selectedTopic by viewModel.selectedTopic.collectAsStateWithLifecycle()
    val isSubmitting by viewModel.isSubmitting.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    val accentColor = TopicStyle.color(selectedTopic)
    val canSubmit = !isSubmitting && content.trim().isNotEmpty()
    val title = if (viewModel.isEditing) "Edit Post" else "New Post"
    val submitLabel = when {
        isSubmitting && viewModel.isEditing -> "Saving..."
        isSubmitting -> "Posting..."
        viewModel.isEditing -> "Save Changes"
        else -> "Post to Bubbler"
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    TextButton(onClick = onBack) {
                        Text("Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = Color.White,
                    actionIconContentColor = Color.White,
                    navigationIconContentColor = Color.White,
                ),
            )
        },
        containerColor = Color.Transparent,
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            accentColor.copy(alpha = 0.75f),
                            Color.Black.copy(alpha = 0.7f),
                            Color.Black.copy(alpha = 0.9f),
                        ),
                    ),
                )
                .padding(innerPadding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 30.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = if (viewModel.isEditing) "Edit Bubble" else "Share a Bubble",
                        color = Color.White,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Black,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        text = if (viewModel.isEditing) {
                            "Update your post content or topic."
                        } else {
                            "Write your post and pick a topic for the feed."
                        },
                        color = Color.White.copy(alpha = 0.75f),
                        style = MaterialTheme.typography.bodyMedium,
                        textAlign = TextAlign.Center,
                    )
                }

                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "Content",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    OutlinedTextField(
                        value = content,
                        onValueChange = viewModel::updateContent,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp)),
                        minLines = 6,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White,
                            focusedContainerColor = Color.White.copy(alpha = 0.08f),
                            unfocusedContainerColor = Color.White.copy(alpha = 0.08f),
                            cursorColor = Color.White,
                            focusedBorderColor = Color.White.copy(alpha = 0.12f),
                            unfocusedBorderColor = Color.White.copy(alpha = 0.12f),
                        ),
                    )
                }

                TopicPicker(
                    selectedTopic = selectedTopic,
                    onTopicSelected = viewModel::selectTopic,
                )

                errorMessage?.let { message ->
                    Text(
                        text = message,
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color.Red.copy(alpha = 0.2f))
                            .border(1.dp, Color.Red.copy(alpha = 0.32f), RoundedCornerShape(16.dp))
                            .padding(14.dp),
                    )
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(
                            if (canSubmit) {
                                accentColor.copy(alpha = 0.85f)
                            } else {
                                Color.White.copy(alpha = 0.15f)
                            },
                        )
                        .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(18.dp))
                        .clickable(enabled = canSubmit) {
                            viewModel.submit { result ->
                                if (result != null) onSuccess(result)
                            }
                        }
                        .padding(vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
                ) {
                    if (isSubmitting) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            color = Color.White,
                            strokeWidth = 2.dp,
                        )
                    }
                    Text(
                        text = submitLabel,
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}

@Preview(showBackground = true, widthDp = 390, heightDp = 400)
@Composable
private fun CreatePostHeaderPreview() {
    BubblerTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF2196F3).copy(alpha = 0.75f),
                            Color.Black.copy(alpha = 0.85f),
                        ),
                    ),
                )
                .padding(16.dp),
        ) {
            Text(
                text = "Share a Bubble",
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Black,
            )
        }
    }
}

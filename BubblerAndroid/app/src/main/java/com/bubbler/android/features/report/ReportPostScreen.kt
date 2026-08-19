package com.bubbler.android.features.report

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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.CheckBoxOutlineBlank
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.bubbler.android.app.theme.BubblerTheme
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.model.Post
import com.bubbler.android.data.model.ReportReason
import com.bubbler.android.data.repository.BlocksRepository
import com.bubbler.android.features.legal.PrivacyPolicyStubScreen
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Report-post form — mirrors Swift `ReportPostView`.
 *
 * Report submit is local-only until the review-queue API lands.
 * "Block this user too" uses the live block endpoint.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportPostScreen(
    post: Post,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    onSubmitted: () -> Unit = onBack,
    onUnauthorized: () -> Unit = {},
) {
    val viewModel = remember(post.id) { ReportPostViewModel() }
    var showPrivacyPolicy by remember { mutableStateOf(false) }
    if (showPrivacyPolicy) {
        PrivacyPolicyStubScreen(
            onBack = { showPrivacyPolicy = false },
            modifier = modifier,
        )
        return
    }

    val context = LocalContext.current
    val selectedReason by viewModel.selectedReason.collectAsStateWithLifecycle()
    val comments by viewModel.comments.collectAsStateWithLifecycle()
    val alsoBlockUser by viewModel.alsoBlockUser.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    val isSubmitting by viewModel.isSubmitting.collectAsStateWithLifecycle()
    val canSubmit = selectedReason != null && !isSubmitting
    val blockableUsername = post.username?.trim()?.takeIf { it.isNotEmpty() }
    val scope = rememberCoroutineScope()

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text("Report Post") },
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
                            Color.Red.copy(alpha = 0.55f),
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
                        text = "Report this post",
                        color = Color.White,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Black,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        text = "Choose a reason. You can add extra context if it helps.",
                        color = Color.White.copy(alpha = 0.75f),
                        style = MaterialTheme.typography.bodyMedium,
                        textAlign = TextAlign.Center,
                    )
                }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.White.copy(alpha = 0.08f))
                        .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(16.dp))
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = "POST",
                        color = Color.White.copy(alpha = 0.65f),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp,
                    )
                    Text(
                        text = post.content,
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 4,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = "Posted by ${post.authorLabel}",
                        color = Color.White.copy(alpha = 0.7f),
                        style = MaterialTheme.typography.bodySmall,
                    )
                }

                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "Reason",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color.White.copy(alpha = 0.08f))
                            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(16.dp)),
                    ) {
                        ReportReason.entries.forEachIndexed { index, reason ->
                            if (index > 0) {
                                HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
                            }
                            val isSelected = selectedReason == reason
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .semantics {
                                        contentDescription = reason.title
                                        role = Role.RadioButton
                                        selected = isSelected
                                    }
                                    .clickable { viewModel.selectReason(reason) }
                                    .padding(horizontal = 14.dp, vertical = 14.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = reason.title,
                                    color = Color.White,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    modifier = Modifier.weight(1f),
                                )
                                if (isSelected) {
                                    Icon(
                                        imageVector = Icons.Filled.Check,
                                        contentDescription = null,
                                        tint = Color.White,
                                    )
                                }
                            }
                        }
                    }
                }

                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "Other comments",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    OutlinedTextField(
                        value = comments,
                        onValueChange = viewModel::updateComments,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .semantics { contentDescription = "Other comments" },
                        minLines = 5,
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

                if (blockableUsername != null) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color.White.copy(alpha = 0.08f))
                            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(16.dp))
                            .semantics {
                                contentDescription = "Block this user too"
                                role = Role.Checkbox
                                selected = alsoBlockUser
                            }
                            .clickable(enabled = !isSubmitting) {
                                viewModel.setAlsoBlockUser(!alsoBlockUser)
                            }
                            .padding(14.dp),
                        verticalAlignment = Alignment.Top,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(
                            imageVector = if (alsoBlockUser) {
                                Icons.Filled.CheckBox
                            } else {
                                Icons.Filled.CheckBoxOutlineBlank
                            },
                            contentDescription = null,
                            tint = Color.White,
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Block this user too",
                                color = Color.White,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Text(
                                text = "Hide their posts from your feed.",
                                color = Color.White.copy(alpha = 0.7f),
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                }

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "How we handle the information in this report",
                        color = Color.White.copy(alpha = 0.75f),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Text(
                        text = "Privacy Policy",
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        textDecoration = TextDecoration.Underline,
                        modifier = Modifier
                            .semantics { contentDescription = "Privacy Policy" }
                            .clickable { showPrivacyPolicy = true },
                    )
                }

                errorMessage?.let { message ->
                    Text(
                        text = message,
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color.Red.copy(alpha = 0.25f))
                            .border(1.dp, Color.Red.copy(alpha = 0.4f), RoundedCornerShape(16.dp))
                            .padding(14.dp),
                    )
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(
                            if (canSubmit) {
                                Color.Red.copy(alpha = 0.85f)
                            } else {
                                Color.White.copy(alpha = 0.15f)
                            },
                        )
                        .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(18.dp))
                        .semantics { contentDescription = "Submit Report" }
                        .clickable(enabled = canSubmit) {
                            scope.launch {
                                val repo = if (alsoBlockUser) {
                                    BlocksRepository(
                                        apiClient = ApiClient(),
                                        tokenStore = TokenStore(context.applicationContext),
                                    )
                                } else {
                                    null
                                }
                                val submitted = viewModel.submit(
                                    authorUsername = blockableUsername,
                                    blocksRepository = repo,
                                    onUnauthorized = onUnauthorized,
                                )
                                if (submitted) onSubmitted()
                            }
                        }
                        .padding(vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                ) {
                    if (isSubmitting) {
                        CircularProgressIndicator(
                            color = Color.White,
                            strokeWidth = 2.dp,
                            modifier = Modifier.size(22.dp),
                        )
                    } else {
                        Text(
                            text = "Submit Report",
                            color = Color.White,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true, widthDp = 390, heightDp = 800)
@Composable
private fun ReportPostScreenPreview() {
    BubblerTheme {
        ReportPostScreen(
            post = Post(
                id = "preview-post",
                userId = 0,
                username = "preview",
                content = "A sample bubble post for the report form preview.",
                createdAt = Instant.now().minusSeconds(2_700),
                topic = null,
                embedding = null,
            ),
            onBack = {},
        )
    }
}

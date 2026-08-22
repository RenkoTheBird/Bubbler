package com.bubbler.android.features.settings.staff

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.model.StaffReport
import com.bubbler.android.data.model.StaffReportStatus
import com.bubbler.android.data.repository.StaffReportsRepository
import com.bubbler.android.features.settings.SettingsGradient
import com.bubbler.android.features.settings.SettingsLoadingCard
import com.bubbler.android.features.settings.SettingsMessageCard
import com.bubbler.android.features.settings.SettingsSectionCard
import kotlinx.coroutines.launch
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Staff ticket detail — mirrors Swift `StaffReportDetailView`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StaffReportDetailScreen(
    reportId: String,
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val factory = remember(reportId, authSession, apiClient, context) {
        StaffReportDetailViewModelFactory(
            reportId = reportId,
            authSession = authSession,
            staffReportsRepository = StaffReportsRepository(
                apiClient = apiClient,
                tokenStore = TokenStore(context.applicationContext),
            ),
        )
    }
    val viewModel: StaffReportDetailViewModel = viewModel(factory = factory)
    val scope = rememberCoroutineScope()

    val report by viewModel.report.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val isUpdating by viewModel.isUpdating.collectAsStateWithLifecycle()
    val errorTitle by viewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    var isRefreshing by remember { mutableStateOf(false) }

    LaunchedEffect(reportId) {
        viewModel.loadAwait()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Report") },
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
                    viewModel.loadAwait(force = true)
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
                errorMessage?.let { message ->
                    SettingsMessageCard(
                        title = errorTitle,
                        message = message,
                        tint = Color.Red,
                    )
                }

                when {
                    isLoading && report == null -> {
                        SettingsLoadingCard(message = "Fetching ticket details.")
                    }
                    report != null -> {
                        val ticket = report!!
                        SnapshotCard(ticket)
                        IdentityCard(ticket)
                        DetailsCard(ticket)
                        RetentionCard(
                            report = ticket,
                            isUpdating = isUpdating,
                            onUpdateLegalHold = { legalHold ->
                                viewModel.updateLegalHold(legalHold)
                            },
                        )
                        ActionsCard(
                            report = ticket,
                            isUpdating = isUpdating,
                            onUpdateStatus = { status -> viewModel.updateStatus(status) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SnapshotCard(report: StaffReport) {
    SettingsSectionCard(title = "Snapshot") {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                text = report.contentSnapshot,
                color = Color.White,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
            )
            report.topicSnapshot?.takeIf { it.isNotBlank() }?.let { topic ->
                Text(
                    text = "Topic: $topic",
                    color = Color.White.copy(alpha = 0.7f),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            Text(
                text = report.status.title.uppercase(),
                color = Color.White.copy(alpha = 0.85f),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .background(Color.White.copy(alpha = 0.14f), RoundedCornerShape(50))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }
    }
}

@Composable
private fun IdentityCard(report: StaffReport) {
    SettingsSectionCard(title = "Identifiers") {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            InfoRow("Reason", report.reasonTitle)
            InfoRow("Reporter ID", report.reporterId?.toString() ?: "—")
            InfoRow("Post ID", report.postId ?: "—")
            InfoRow("Author ID", report.reportedUserId?.toString() ?: "—")
            InfoRow(
                "Author",
                report.authorUsernameSnapshot?.let { "@$it" } ?: "—",
            )
            InfoRow(
                "Created",
                detailDateFormatter.format(report.createdAt.atZone(ZoneId.systemDefault())),
            )
        }
    }
}

@Composable
private fun DetailsCard(report: StaffReport) {
    SettingsSectionCard(title = "Reporter notes") {
        Text(
            text = report.details?.takeIf { it.isNotBlank() } ?: "No extra details.",
            color = Color.White.copy(alpha = 0.85f),
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun RetentionCard(
    report: StaffReport,
    isUpdating: Boolean,
    onUpdateLegalHold: (Boolean) -> Unit,
) {
    SettingsSectionCard(title = "Retention") {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = "Legal hold",
                    color = Color.White,
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(
                    text = "Prevents auto-purge per retention policy.",
                    color = Color.White.copy(alpha = 0.65f),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            Switch(
                checked = report.legalHold,
                onCheckedChange = onUpdateLegalHold,
                enabled = !isUpdating,
            )
        }
    }
}

@Composable
private fun ActionsCard(
    report: StaffReport,
    isUpdating: Boolean,
    onUpdateStatus: (StaffReportStatus) -> Unit,
) {
    SettingsSectionCard(title = "Triage") {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                text = "Mark the ticket without removing content. Enforcement is a later step.",
                color = Color.White.copy(alpha = 0.65f),
                style = MaterialTheme.typography.bodySmall,
            )
            if (report.status != StaffReportStatus.IN_REVIEW) {
                ActionButton(
                    title = "Mark In Review",
                    enabled = !isUpdating,
                    showProgress = isUpdating,
                    onClick = { onUpdateStatus(StaffReportStatus.IN_REVIEW) },
                )
            }
            if (report.status != StaffReportStatus.RESOLVED) {
                ActionButton(
                    title = "Resolve",
                    enabled = !isUpdating,
                    showProgress = isUpdating,
                    onClick = { onUpdateStatus(StaffReportStatus.RESOLVED) },
                )
            }
            if (report.status != StaffReportStatus.DISMISSED) {
                ActionButton(
                    title = "Dismiss",
                    enabled = !isUpdating,
                    showProgress = isUpdating,
                    onClick = { onUpdateStatus(StaffReportStatus.DISMISSED) },
                )
            }
        }
    }
}

@Composable
private fun ActionButton(
    title: String,
    enabled: Boolean,
    showProgress: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .semantics {
                role = Role.Button
                contentDescription = title
            }
            .background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            color = Color.White.copy(alpha = if (enabled) 1f else 0.55f),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        if (showProgress) {
            CircularProgressIndicator(
                color = Color.White,
                strokeWidth = 2.dp,
                modifier = Modifier
                    .padding(start = 8.dp)
                    .size(18.dp),
            )
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.55f),
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.width(88.dp),
        )
        Spacer(modifier = Modifier.width(4.dp))
        Text(
            text = value,
            color = Color.White.copy(alpha = 0.9f),
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
        )
    }
}

private val detailDateFormatter: DateTimeFormatter =
    DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)

package com.bubbler.android.features.settings.staff

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
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
import com.bubbler.android.features.settings.SettingsHeader
import com.bubbler.android.features.settings.SettingsLoadingCard
import com.bubbler.android.features.settings.SettingsMessageCard
import com.bubbler.android.features.settings.SettingsSectionCard
import kotlinx.coroutines.launch
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Staff report queue — mirrors Swift `StaffReportsView`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StaffReportsScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    onBack: () -> Unit,
    onOpenReport: (StaffReport) -> Unit,
) {
    val context = LocalContext.current
    val factory = remember(authSession, apiClient, context) {
        StaffReportsViewModelFactory(
            authSession = authSession,
            staffReportsRepository = StaffReportsRepository(
                apiClient = apiClient,
                tokenStore = TokenStore(context.applicationContext),
            ),
        )
    }
    val viewModel: StaffReportsViewModel = viewModel(factory = factory)
    val scope = rememberCoroutineScope()

    val reports by viewModel.reports.collectAsStateWithLifecycle()
    val selectedStatus by viewModel.selectedStatus.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val errorTitle by viewModel.errorTitle.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    var isRefreshing by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.loadReportsAwait(force = true)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Reports") },
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
                    viewModel.loadReportsAwait(force = true)
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
                    title = "Report Queue",
                    subtitle = "Review open tickets and mark them triaged or closed. Removal stays a separate step.",
                )

                StatusFilterRow(
                    selected = selectedStatus,
                    onSelect = { status -> viewModel.changeStatusFilter(status) },
                )

                errorMessage?.let { message ->
                    SettingsMessageCard(
                        title = errorTitle,
                        message = message,
                        tint = Color.Red,
                    )
                }

                when {
                    isLoading && reports.isEmpty() -> {
                        SettingsLoadingCard(message = "Fetching reports.")
                    }
                    reports.isEmpty() -> {
                        SettingsSectionCard(
                            title = "No ${selectedStatus.title.lowercase()} reports",
                        ) {
                            Text(
                                text = "When users report posts, matching tickets show up here for triage.",
                                color = Color.White.copy(alpha = 0.85f),
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                    else -> {
                        SettingsSectionCard(
                            title = selectedStatus.title,
                            subtitle = if (reports.size == 1) "1 ticket" else "${reports.size} tickets",
                        ) {
                            reports.forEachIndexed { index, report ->
                                ReportRow(
                                    report = report,
                                    onClick = { onOpenReport(report) },
                                )
                                if (index < reports.lastIndex) {
                                    HorizontalDivider(
                                        color = Color.White.copy(alpha = 0.12f),
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
private fun StatusFilterRow(
    selected: StaffReportStatus,
    onSelect: (StaffReportStatus) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        StaffReportStatus.entries.forEach { status ->
            val isSelected = status == selected
            Text(
                text = status.title,
                color = if (isSelected) Color.Black else Color.White.copy(alpha = 0.85f),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .semantics {
                        role = Role.Button
                        contentDescription = status.title
                    }
                    .background(
                        color = if (isSelected) Color.White else Color.White.copy(alpha = 0.12f),
                        shape = RoundedCornerShape(50),
                    )
                    .clickable { onSelect(status) }
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )
        }
    }
}

@Composable
private fun ReportRow(
    report: StaffReport,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .semantics {
                role = Role.Button
                contentDescription = report.reasonTitle
            }
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = report.reasonTitle,
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = report.contentSnapshot,
                color = Color.White.copy(alpha = 0.75f),
                style = MaterialTheme.typography.bodySmall,
                maxLines = 2,
            )
            Text(
                text = metaLine(report),
                color = Color.White.copy(alpha = 0.55f),
                style = MaterialTheme.typography.labelSmall,
            )
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.4f),
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

private val reportDateFormatter: DateTimeFormatter =
    DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)

private fun metaLine(report: StaffReport): String {
    val author = report.authorUsernameSnapshot?.let { "@$it" } ?: "unknown author"
    val whenText = reportDateFormatter.format(
        report.createdAt.atZone(ZoneId.systemDefault()),
    )
    return "$author · $whenText"
}

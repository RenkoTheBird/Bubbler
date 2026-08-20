package com.bubbler.android.features.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.bubbler.android.app.navigation.Routes
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.repository.UserRepository
import com.bubbler.android.features.settings.account.DeleteAccountScreen
import com.bubbler.android.features.settings.account.EmailSettingsScreen
import com.bubbler.android.features.settings.account.PasswordSecurityScreen
import com.bubbler.android.features.settings.account.ProfileInfoScreen
import com.bubbler.android.features.settings.blocks.BlockedUsersScreen
import com.bubbler.android.features.settings.preferences.PreferencesScreen
import com.bubbler.android.features.settings.staff.StaffReportDetailScreen
import com.bubbler.android.features.settings.staff.StaffReportsScreen
import java.net.URLDecoder

/**
 * Settings tab shell — hub list plus nested destinations (Phase 7 complete).
 */
@Composable
fun SettingsTabScreen(
    authSession: AuthSession,
    apiClient: ApiClient,
    modifier: Modifier = Modifier,
    navController: NavHostController = rememberNavController(),
) {
    val context = LocalContext.current
    val userRepository = remember(apiClient, context) {
        UserRepository(apiClient, TokenStore(context.applicationContext))
    }
    val dataExportFactory = remember(authSession, context, userRepository) {
        DataExportViewModelFactory(
            authSession = authSession,
            contentResolver = context.applicationContext.contentResolver,
            userRepository = userRepository,
        )
    }
    val dataExportViewModel: DataExportViewModel = viewModel(factory = dataExportFactory)
    val isExporting by dataExportViewModel.isExporting.collectAsStateWithLifecycle()
    val exportErrorTitle by dataExportViewModel.errorTitle.collectAsStateWithLifecycle()
    val exportErrorMessage by dataExportViewModel.errorMessage.collectAsStateWithLifecycle()
    val isStaff by authSession.isStaff.collectAsStateWithLifecycle()

    val createDocumentLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/json"),
    ) { uri ->
        dataExportViewModel.onSaveLocationChosen(uri)
    }

    LaunchedEffect(dataExportViewModel) {
        dataExportViewModel.createDocumentRequests.collect { fileName ->
            createDocumentLauncher.launch(fileName)
        }
    }

    LaunchedEffect(Unit) {
        authSession.refreshStaffAccess()
    }

    NavHost(
        navController = navController,
        startDestination = Routes.SETTINGS_HOME,
        modifier = modifier.fillMaxSize(),
    ) {
        composable(Routes.SETTINGS_HOME) {
            SettingsScreen(
                onNavigate = { destination ->
                    navController.navigate(destination.route)
                },
                onSignOut = { authSession.signOut() },
                onExportData = { dataExportViewModel.startExport() },
                isStaff = isStaff,
                isExporting = isExporting,
                exportErrorTitle = exportErrorTitle,
                exportErrorMessage = exportErrorMessage,
                onDismissExportError = { dataExportViewModel.dismissError() },
            )
        }
        composable(Routes.SETTINGS_PROFILE_INFO) {
            ProfileInfoScreen(
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.SETTINGS_EMAIL) {
            EmailSettingsScreen(
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.SETTINGS_PASSWORD) {
            PasswordSecurityScreen(
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.SETTINGS_DELETE_ACCOUNT) {
            DeleteAccountScreen(
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.SETTINGS_PREFERENCES) {
            PreferencesScreen(
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.SETTINGS_BLOCKED) {
            BlockedUsersScreen(
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.SETTINGS_REPORTS) {
            StaffReportsScreen(
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
                onOpenReport = { report ->
                    navController.navigate(Routes.settingsReportDetail(report.id))
                },
            )
        }
        composable(
            route = Routes.SETTINGS_REPORT_DETAIL,
            arguments = listOf(
                navArgument("reportId") { type = NavType.StringType },
            ),
        ) { entry ->
            val encodedId = entry.arguments?.getString("reportId").orEmpty()
            val reportId = URLDecoder.decode(encodedId, Charsets.UTF_8.name())
            StaffReportDetailScreen(
                reportId = reportId,
                authSession = authSession,
                apiClient = apiClient,
                onBack = { navController.popBackStack() },
            )
        }
    }
}

private val SettingsDestination.route: String
    get() = when (this) {
        SettingsDestination.ProfileInfo -> Routes.SETTINGS_PROFILE_INFO
        SettingsDestination.Email -> Routes.SETTINGS_EMAIL
        SettingsDestination.Password -> Routes.SETTINGS_PASSWORD
        SettingsDestination.DeleteAccount -> Routes.SETTINGS_DELETE_ACCOUNT
        SettingsDestination.BlockedUsers -> Routes.SETTINGS_BLOCKED
        SettingsDestination.Preferences -> Routes.SETTINGS_PREFERENCES
        SettingsDestination.Reports -> Routes.SETTINGS_REPORTS
    }

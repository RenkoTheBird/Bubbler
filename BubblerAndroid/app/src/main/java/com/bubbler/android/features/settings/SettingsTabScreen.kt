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
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.bubbler.android.app.navigation.Routes
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.features.settings.account.DeleteAccountScreen
import com.bubbler.android.features.settings.account.EmailSettingsScreen
import com.bubbler.android.features.settings.account.PasswordSecurityScreen
import com.bubbler.android.features.settings.account.ProfileInfoScreen
import com.bubbler.android.features.settings.blocks.BlockedUsersScreen
import com.bubbler.android.features.settings.preferences.PreferencesScreen

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
    val dataExportFactory = remember(authSession, context) {
        DataExportViewModelFactory(
            authSession = authSession,
            contentResolver = context.applicationContext.contentResolver,
        )
    }
    val dataExportViewModel: DataExportViewModel = viewModel(factory = dataExportFactory)
    val isExporting by dataExportViewModel.isExporting.collectAsStateWithLifecycle()
    val exportErrorTitle by dataExportViewModel.errorTitle.collectAsStateWithLifecycle()
    val exportErrorMessage by dataExportViewModel.errorMessage.collectAsStateWithLifecycle()

    val createDocumentLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/zip"),
    ) { uri ->
        dataExportViewModel.onSaveLocationChosen(uri)
    }

    LaunchedEffect(dataExportViewModel) {
        dataExportViewModel.createDocumentRequests.collect { fileName ->
            createDocumentLauncher.launch(fileName)
        }
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
    }

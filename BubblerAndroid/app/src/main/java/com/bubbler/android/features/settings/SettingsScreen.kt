package com.bubbler.android.features.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bubbler.android.app.theme.BubblerTheme

/**
 * Settings hub — mirrors Swift `SettingsView`.
 *
 * Subpages (account, preferences, blocks) are reached via [SettingsDestination]
 * callbacks; legal rows stay no-ops until product links land.
 */
@Composable
fun SettingsScreen(
    onNavigate: (SettingsDestination) -> Unit,
    onSignOut: () -> Unit,
    onExportData: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.Black,
                        Color(0xFF1565C0).copy(alpha = 0.6f),
                        Color(0xFF303F9F).copy(alpha = 0.8f),
                    ),
                ),
            ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 30.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            Spacer(modifier = Modifier.height(20.dp))

            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = "Settings",
                    color = Color.White,
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.5).sp,
                )
                Text(
                    text = "Control your Bubbler experience",
                    color = Color.White.copy(alpha = 0.7f),
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                )
            }

            SettingsSection(title = "Account") {
                SettingsRow(
                    icon = Icons.Filled.Person,
                    title = "Profile Information",
                    onClick = { onNavigate(SettingsDestination.ProfileInfo) },
                )
                SettingsRow(
                    icon = Icons.Filled.Email,
                    title = "Email Settings",
                    onClick = { onNavigate(SettingsDestination.Email) },
                )
                SettingsRow(
                    icon = Icons.Filled.Lock,
                    title = "Password & Security",
                    onClick = { onNavigate(SettingsDestination.Password) },
                )
                SettingsRow(
                    icon = Icons.Filled.Download,
                    title = "Export Data",
                    onClick = onExportData,
                )
                SettingsRow(
                    icon = Icons.AutoMirrored.Filled.Logout,
                    title = "Log Out",
                    onClick = onSignOut,
                )
                SettingsRow(
                    icon = Icons.Filled.Delete,
                    title = "Delete Account",
                    tint = Color.Red.copy(alpha = 0.9f),
                    onClick = { onNavigate(SettingsDestination.DeleteAccount) },
                )
            }

            SettingsSection(title = "Users") {
                SettingsRow(
                    icon = Icons.Filled.Block,
                    title = "Blocked",
                    onClick = { onNavigate(SettingsDestination.BlockedUsers) },
                )
            }

            SettingsSection(title = "Bubble System") {
                SettingsRow(
                    icon = Icons.Filled.Tune,
                    title = "Recommendation Preferences",
                    onClick = { onNavigate(SettingsDestination.Preferences) },
                )
            }

            SettingsSection(title = "About") {
                // Privacy / Terms / Guidelines links TBD (same as iOS).
                SettingsRow(
                    icon = Icons.Filled.PrivacyTip,
                    title = "Privacy Policy",
                    onClick = { },
                )
                SettingsRow(
                    icon = Icons.Filled.Description,
                    title = "Terms of Service",
                    onClick = { },
                )
                SettingsRow(
                    icon = Icons.Filled.Groups,
                    title = "Community Guidelines",
                    onClick = { },
                )
            }
        }
    }
}

enum class SettingsDestination {
    ProfileInfo,
    Email,
    Password,
    DeleteAccount,
    BlockedUsers,
    Preferences,
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = title.uppercase(),
            color = Color.White.copy(alpha = 0.6f),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.sp,
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(18.dp))
                .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(18.dp))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            content()
        }
    }
}

@Composable
private fun SettingsRow(
    icon: ImageVector,
    title: String,
    onClick: () -> Unit,
    tint: Color = Color.White.copy(alpha = 0.9f),
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .semantics {
                role = Role.Button
                contentDescription = title
            }
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint.copy(alpha = 0.9f),
            modifier = Modifier.size(22.dp),
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = title,
            color = tint,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
        )
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.4f),
            modifier = Modifier.size(20.dp),
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun SettingsScreenPreview() {
    BubblerTheme {
        SettingsScreen(
            onNavigate = {},
            onSignOut = {},
            onExportData = {},
        )
    }
}

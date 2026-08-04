package com.bubbler.android.features.settings.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.UserRepository

@Composable
internal fun rememberAccountViewModel(
    authSession: AuthSession,
    apiClient: ApiClient,
): AccountViewModel {
    val context = LocalContext.current
    val factory = remember(authSession, apiClient, context) {
        val tokenStore = TokenStore(context.applicationContext)
        AccountViewModelFactory(
            authSession = authSession,
            userRepository = UserRepository(apiClient, tokenStore),
            authRepository = AuthRepository(apiClient),
        )
    }
    return viewModel(factory = factory)
}

@Composable
internal fun SettingsFormField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    isPassword: Boolean = false,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.8f),
            style = MaterialTheme.typography.labelMedium,
        )
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = {
                Text(placeholder, color = Color.White.copy(alpha = 0.55f))
            },
            singleLine = true,
            visualTransformation = if (isPassword) {
                PasswordVisualTransformation()
            } else {
                VisualTransformation.None
            },
            keyboardOptions = keyboardOptions,
            shape = RoundedCornerShape(14.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                cursorColor = Color.White,
                focusedBorderColor = Color.Transparent,
                unfocusedBorderColor = Color.Transparent,
                focusedContainerColor = Color.White.copy(alpha = 0.2f),
                unfocusedContainerColor = Color.White.copy(alpha = 0.2f),
            ),
        )
    }
}

@Composable
internal fun SettingsPrimaryButton(
    label: String,
    enabled: Boolean,
    isWorking: Boolean,
    onClick: () -> Unit,
    destructive: Boolean = false,
) {
    Button(
        onClick = onClick,
        enabled = enabled && !isWorking,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = if (destructive) Color.Red.copy(alpha = 0.9f) else Color.White,
            contentColor = if (destructive) Color.White else Color.Black,
            disabledContainerColor = if (destructive) {
                Color.Red.copy(alpha = 0.45f)
            } else {
                Color.White.copy(alpha = 0.55f)
            },
            disabledContentColor = if (destructive) {
                Color.White.copy(alpha = 0.7f)
            } else {
                Color.Black.copy(alpha = 0.7f)
            },
        ),
    ) {
        Row {
            if (isWorking) {
                CircularProgressIndicator(
                    color = if (destructive) Color.White else Color.Black,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(
                text = label,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(vertical = 8.dp),
            )
        }
    }
}

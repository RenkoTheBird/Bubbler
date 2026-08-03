package com.bubbler.android.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.bubbler.android.core.auth.AgeGate
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.ui.components.BubblerLogo
import com.bubbler.android.features.auth.components.AuthErrorText
import com.bubbler.android.features.auth.components.AuthFieldBg
import com.bubbler.android.features.auth.components.AuthGradientBackground
import com.bubbler.android.features.auth.components.AuthLabeledField
import com.bubbler.android.features.auth.components.AuthOnGradient
import com.bubbler.android.features.auth.components.AuthPrimaryButton
import com.bubbler.android.features.auth.components.AuthSubtitle
import com.bubbler.android.features.auth.components.AuthTitle
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateAccountScreen(
    authSession: AuthSession,
    onLogin: () -> Unit,
) {
    var username by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var dateOfBirth by remember {
        mutableStateOf(LocalDate.now().minusYears(18))
    }
    var showDatePicker by remember { mutableStateOf(false) }

    val authError by authSession.authError.collectAsStateWithLifecycle()
    val isWorking by authSession.isWorking.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    val isOldEnough = AgeGate.isOldEnough(dateOfBirth)
    val ageGateError = if (isOldEnough) null else AgeGate.underageMessage

    AuthGradientBackground {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(modifier = Modifier.height(36.dp))
            BubblerLogo(size = 100.dp)
            Spacer(modifier = Modifier.height(18.dp))
            AuthTitle("Create Account", fontSizeSp = 36)
            Spacer(modifier = Modifier.height(8.dp))
            AuthSubtitle("Join your interest bubbles")
            Spacer(modifier = Modifier.height(28.dp))

            AuthLabeledField(
                label = "Username",
                value = username,
                onValueChange = { username = it },
                placeholder = "Choose a username",
                keyboardOptions = KeyboardOptions(
                    imeAction = ImeAction.Next,
                    autoCorrectEnabled = false,
                ),
            )
            Spacer(modifier = Modifier.height(16.dp))
            AuthLabeledField(
                label = "Email",
                value = email,
                onValueChange = { email = it },
                placeholder = "Enter your email",
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Next,
                    autoCorrectEnabled = false,
                ),
            )
            Spacer(modifier = Modifier.height(16.dp))

            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "Date of birth",
                    color = AuthOnGradient.copy(alpha = 0.8f),
                    style = MaterialTheme.typography.labelMedium,
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = dateOfBirth.format(DateTimeFormatter.ISO_LOCAL_DATE),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(AuthFieldBg)
                        .clickable { showDatePicker = true }
                        .padding(16.dp),
                    color = AuthOnGradient,
                )
                if (ageGateError != null) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = ageGateError,
                        color = AuthOnGradient,
                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            AuthLabeledField(
                label = "Password",
                value = password,
                onValueChange = { password = it },
                placeholder = "Create a password",
                isPassword = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Next,
                ),
            )
            Spacer(modifier = Modifier.height(16.dp))
            AuthLabeledField(
                label = "Confirm Password",
                value = confirmPassword,
                onValueChange = { confirmPassword = it },
                placeholder = "Re-enter your password",
                isPassword = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done,
                ),
            )

            if (authError != null) {
                Spacer(modifier = Modifier.height(12.dp))
                AuthErrorText(authError!!)
            }

            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = agreementText(),
                color = AuthOnGradient.copy(alpha = 0.8f),
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(16.dp))
            AuthPrimaryButton(
                label = "Create Account",
                enabled = isOldEnough,
                isWorking = isWorking,
                onClick = {
                    scope.launch {
                        authSession.createAccount(
                            username = username,
                            email = email,
                            password = password,
                            confirmPassword = confirmPassword,
                            dateOfBirth = dateOfBirth,
                        )
                    }
                },
            )

            Spacer(modifier = Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Already have an account?",
                    color = AuthOnGradient.copy(alpha = 0.8f),
                )
                TextButton(onClick = onLogin) {
                    Text(
                        text = "Log in",
                        color = AuthOnGradient,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
            Text(
                text = "Your feed, shaped by your interests",
                color = AuthOnGradient.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodySmall,
            )
            Spacer(modifier = Modifier.height(24.dp))
        }
    }

    if (showDatePicker) {
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = dateOfBirth
                .atStartOfDay(ZoneOffset.UTC)
                .toInstant()
                .toEpochMilli(),
            yearRange = IntRange(LocalDate.now().year - 120, LocalDate.now().year),
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        pickerState.selectedDateMillis?.let { millis ->
                            dateOfBirth = Instant.ofEpochMilli(millis)
                                .atZone(ZoneOffset.UTC)
                                .toLocalDate()
                        }
                        showDatePicker = false
                    },
                ) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text("Cancel")
                }
            },
        ) {
            DatePicker(state = pickerState)
        }
    }
}

private fun agreementText() = buildAnnotatedString {
    append("By signing up, you agree to Bubbler's ")
    withStyle(
        SpanStyle(
            color = Color.White,
            textDecoration = TextDecoration.Underline,
            fontWeight = FontWeight.SemiBold,
        ),
    ) {
        append("Terms of Use")
    }
    append(" and ")
    withStyle(
        SpanStyle(
            color = Color.White,
            textDecoration = TextDecoration.Underline,
            fontWeight = FontWeight.SemiBold,
        ),
    ) {
        append("Privacy Policy")
    }
}

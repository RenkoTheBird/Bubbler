package com.bubbler.android.features.auth.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val AuthBlue = Color(0xFF1565C0)
val AuthCyan = Color(0xFF4DD0E1)
val AuthFieldBg = Color.White.copy(alpha = 0.2f)
val AuthOnGradient = Color.White

@Composable
fun AuthGradientBackground(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF0D47A1),
                        Color(0xFF26C6DA),
                        Color(0xFF1565C0),
                    ),
                ),
            ),
    ) {
        content()
    }
}

/** Lightweight brand mark until Phase 3 `BubblerLogo`. */
@Composable
fun AuthBrandMark(size: Dp = 120.dp) {
    Box(
        modifier = Modifier.size(size),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(size * 0.92f)
                .clip(CircleShape)
                .background(AuthCyan.copy(alpha = 0.35f)),
        )
        Box(
            modifier = Modifier
                .size(size * 0.55f)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.9f)),
        )
        Box(
            modifier = Modifier
                .padding(start = size * 0.18f, top = size * 0.12f)
                .size(size * 0.22f)
                .align(Alignment.TopEnd)
                .clip(CircleShape)
                .background(AuthCyan.copy(alpha = 0.75f)),
        )
    }
}

@Composable
fun AuthLabeledField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    isPassword: Boolean = false,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    singleLine: Boolean = true,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = label,
            color = AuthOnGradient.copy(alpha = 0.8f),
            style = MaterialTheme.typography.labelMedium,
        )
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = {
                Text(placeholder, color = AuthOnGradient.copy(alpha = 0.55f))
            },
            singleLine = singleLine,
            visualTransformation = if (isPassword) {
                PasswordVisualTransformation()
            } else {
                VisualTransformation.None
            },
            keyboardOptions = keyboardOptions,
            keyboardActions = keyboardActions,
            shape = RoundedCornerShape(14.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = AuthOnGradient,
                unfocusedTextColor = AuthOnGradient,
                cursorColor = AuthOnGradient,
                focusedBorderColor = Color.Transparent,
                unfocusedBorderColor = Color.Transparent,
                focusedContainerColor = AuthFieldBg,
                unfocusedContainerColor = AuthFieldBg,
            ),
        )
    }
}

@Composable
fun AuthErrorText(message: String, modifier: Modifier = Modifier) {
    Text(
        text = message,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 6.dp),
        color = AuthOnGradient,
        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
        textAlign = TextAlign.Center,
    )
}

@Composable
fun AuthPrimaryButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isWorking: Boolean = false,
) {
    Button(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        enabled = enabled && !isWorking,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.White,
            contentColor = AuthBlue,
            disabledContainerColor = Color.White.copy(alpha = 0.55f),
            disabledContentColor = AuthBlue.copy(alpha = 0.7f),
        ),
    ) {
        if (isWorking) {
            CircularProgressIndicator(
                modifier = Modifier
                    .padding(vertical = 4.dp)
                    .size(22.dp),
                color = AuthBlue,
                strokeWidth = 2.dp,
            )
        } else {
            Text(
                text = label,
                modifier = Modifier.padding(vertical = 6.dp),
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}

@Composable
fun AuthTitle(text: String, fontSizeSp: Int = 50) {
    Text(
        text = text,
        color = AuthOnGradient,
        fontSize = fontSizeSp.sp,
        fontWeight = FontWeight.Black,
        letterSpacing = 2.sp,
    )
}

@Composable
fun AuthSubtitle(text: String) {
    Text(
        text = text,
        color = AuthOnGradient.copy(alpha = 0.85f),
        style = MaterialTheme.typography.bodyMedium,
        textAlign = TextAlign.Center,
    )
}

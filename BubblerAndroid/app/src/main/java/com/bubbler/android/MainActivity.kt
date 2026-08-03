package com.bubbler.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.bubbler.android.app.BubblerApp
import com.bubbler.android.app.theme.BubblerTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            BubblerTheme {
                BubblerApp()
            }
        }
    }
}

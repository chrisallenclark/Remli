package com.chrisallenclark.remli

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.remember
import com.chrisallenclark.remli.capabilities.AndroidDeviceFacts
import com.chrisallenclark.remli.capabilities.DeviceCapabilities
import com.chrisallenclark.remli.ui.theme.RemliPalette

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Drawn under the status and navigation bars, as iOS does. Enforced from Android 15
        // anyway; doing it everywhere means one layout, not two.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        setContent {
            val capabilities = remember { DeviceCapabilities.from(AndroidDeviceFacts.read(applicationContext)) }
            val palette = if (isSystemInDarkTheme()) RemliPalette.Dark else RemliPalette.Light
            FoundationScreen(capabilities, palette)
        }
    }
}

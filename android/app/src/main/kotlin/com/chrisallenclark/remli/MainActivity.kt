package com.chrisallenclark.remli

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.chrisallenclark.remli.ui.RemliApp

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Drawn under the status and navigation bars, as iOS does. Enforced from Android 15
        // anyway; doing it everywhere means one layout, not two.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        val app = application as RemliApplication
        setContent {
            RemliApp(
                store = app.store,
                appearanceStore = app.appearance,
                capabilities = app.capabilities,
                // The app's own appearance setting can differ from the phone's, so the
                // status bar icons follow the app rather than the system.
                onDarkChanged = { dark ->
                    val style = if (dark) SystemBarStyle.dark(Color.TRANSPARENT)
                    else SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
                    enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
                },
            )
        }
    }
}

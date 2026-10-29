package com.chrisallenclark.remli

import android.graphics.Bitmap
import android.os.Build
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File

/**
 * Real-device screenshots from inside a test, status bar and all — what the iOS reference
 * screens are compared against. Saved to the app's external files directory; CI pulls them
 * off the emulator after the run.
 */
object Shots {
    fun dir(): File {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        return File(context.getExternalFilesDir(null), "screens").apply { mkdirs() }
    }

    fun take(name: String) {
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        Thread.sleep(700) // let springs settle
        val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot() ?: return
        File(dir(), "api${Build.VERSION.SDK_INT}_$name.png").outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
    }
}

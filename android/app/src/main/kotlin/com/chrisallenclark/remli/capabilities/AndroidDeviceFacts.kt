package com.chrisallenclark.remli.capabilities

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.speech.SpeechRecognizer

/** Reads [DeviceFacts] from the running phone. The only part of capabilities that touches Android. */
object AndroidDeviceFacts {

    fun read(context: Context): DeviceFacts {
        val activityManager = context.getSystemService(ActivityManager::class.java)
        val memory = ActivityManager.MemoryInfo().also { activityManager?.getMemoryInfo(it) }

        return DeviceFacts(
            sdkInt = Build.VERSION.SDK_INT,
            isLowRamDevice = activityManager?.isLowRamDevice ?: false,
            totalMemoryBytes = memory.totalMem,
            hasOnDeviceSpeechRecognizer = hasOnDeviceRecognizer(context),
        )
    }

    /**
     * Whether an on-device recognition service exists. It may still need a language pack
     * downloaded before first use; voice capture (A2) checks and offers that download, and
     * offers typing until it is done.
     */
    private fun hasOnDeviceRecognizer(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return runCatching { SpeechRecognizer.isOnDeviceRecognitionAvailable(context) }.getOrDefault(false)
    }
}

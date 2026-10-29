package com.chrisallenclark.remli.design

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Light, dark, or whatever the phone is doing. Port of Appearance.swift.
 *
 * Stored as a raw string under the same key iOS uses, so the value is legible and reordering
 * the cases can never change what a device already chose. A property of this device, not of
 * the library — never synced.
 */
enum class Appearance(val raw: String, val label: String, val symbol: Symbol) {
    System("system", "System", Symbol.Iphone),
    Light("light", "Light", Symbol.SunMax),
    Dark("dark", "Dark", Symbol.Moon);

    /** Null means follow the phone. */
    val isDark: Boolean? get() = when (this) {
        System -> null
        Light -> false
        Dark -> true
    }

    companion object {
        /** Unset, or a value this build does not understand, both mean follow the phone. */
        fun from(raw: String?): Appearance = entries.firstOrNull { it.raw == raw } ?: System

        /**
         * What Settings offers. Android 8 and 9 have no system-wide dark mode, so there is
         * nothing for "System" to follow and the choice is Light or Dark.
         */
        fun options(followsSystemAppearance: Boolean): List<Appearance> =
            if (followsSystemAppearance) entries else listOf(Light, Dark)
    }
}

class AppearanceStore(private val prefs: SharedPreferences) {

    var appearance: Appearance by mutableStateOf(Appearance.from(prefs.getString(KEY, null)))
        private set

    fun set(value: Appearance) {
        if (value == appearance) return
        appearance = value
        prefs.edit().putString(KEY, value.raw).apply()
    }

    companion object {
        const val KEY = "remli.appearance"

        fun from(context: Context) =
            AppearanceStore(context.getSharedPreferences("remli", Context.MODE_PRIVATE))
    }
}

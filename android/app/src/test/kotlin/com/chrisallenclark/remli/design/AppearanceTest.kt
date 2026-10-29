package com.chrisallenclark.remli.design

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** Port of Tests/AppearanceTests.swift, case for case, plus the Android 8–9 option set. */
@RunWith(RobolectricTestRunner::class)
class AppearanceTest {

    private val prefs get() = ApplicationProvider.getApplicationContext<Context>()
        .getSharedPreferences("appearance-test", Context.MODE_PRIVATE)

    @Before fun clear() = prefs.edit().clear().commit().let { }

    @Test fun `each option maps to the right colour scheme`() {
        assertNull(Appearance.System.isDark)
        assertEquals(false, Appearance.Light.isDark)
        assertEquals(true, Appearance.Dark.isDark)
    }

    @Test fun `every option is presentable`() {
        for (option in Appearance.entries) assert(option.label.isNotEmpty())
        assertEquals(3, Appearance.entries.size)
    }

    @Test fun `raw values are stable, because they are what lands in storage`() {
        assertEquals(listOf("system", "light", "dark"), Appearance.entries.map { it.raw })
        assertEquals("remli.appearance", AppearanceStore.KEY)
    }

    @Test fun `a fresh install follows the phone`() = assertEquals(Appearance.System, AppearanceStore(prefs).appearance)

    @Test fun `a choice survives a relaunch`() {
        AppearanceStore(prefs).set(Appearance.Light)
        assertEquals(Appearance.Light, AppearanceStore(prefs).appearance)
    }

    @Test fun `a value this build does not understand falls back to following the phone`() {
        prefs.edit().putString(AppearanceStore.KEY, "sepia").commit()
        assertEquals(Appearance.System, AppearanceStore(prefs).appearance)
    }

    @Test fun `setting the same value again does not churn storage`() {
        val store = AppearanceStore(prefs)
        store.set(Appearance.Dark)
        store.set(Appearance.Dark)
        assertEquals("dark", prefs.getString(AppearanceStore.KEY, null))
    }

    @Test fun `going back to System is recorded, not just forgotten`() {
        val store = AppearanceStore(prefs)
        store.set(Appearance.Dark)
        store.set(Appearance.System)
        assertEquals("system", prefs.getString(AppearanceStore.KEY, null))
        assertEquals(Appearance.System, AppearanceStore(prefs).appearance)
    }

    @Test fun `Android 8 and 9 are offered Light and Dark only`() {
        assertEquals(listOf(Appearance.Light, Appearance.Dark), Appearance.options(followsSystemAppearance = false))
        assertEquals(Appearance.entries, Appearance.options(followsSystemAppearance = true))
    }
}

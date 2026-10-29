package com.chrisallenclark.remli

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chrisallenclark.remli.capabilities.AndroidDeviceFacts
import com.chrisallenclark.remli.capabilities.DeviceCapabilities
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Runs on real Android builds in the emulator matrix: the app launches, draws, and reads
 * this device's capabilities without crashing — on Android 8, 10 and 16 alike.
 */
@RunWith(AndroidJUnit4::class)
class LaunchTest {

    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    @Test
    fun launchesAndShowsTitle() {
        rule.onNodeWithTag("title").assertIsDisplayed()
        rule.onNodeWithTag("capabilities").assertIsDisplayed()
    }

    @Test
    fun capabilityReadoutMatchesThisDevice() {
        val expected = DeviceCapabilities.from(AndroidDeviceFacts.read(rule.activity))
        capabilityLines(expected).forEach { (label, _) ->
            rule.onNodeWithText(label).assertExists()
        }
    }
}

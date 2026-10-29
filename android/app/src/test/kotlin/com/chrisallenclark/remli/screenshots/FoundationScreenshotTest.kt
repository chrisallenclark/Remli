package com.chrisallenclark.remli.screenshots

import com.chrisallenclark.remli.FoundationScreen
import com.chrisallenclark.remli.capabilities.DeviceCapabilities
import com.chrisallenclark.remli.capabilities.DeviceFacts
import com.chrisallenclark.remli.ui.theme.RemliPalette
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Renders screens on the JVM — no emulator — across the screen sizes and settings Android
 * phones actually ship with.
 *
 * The three widths bracket the real market: 360dp is a small or budget phone (Galaxy A0x,
 * Moto E), 411dp is the common size (Pixel, Galaxy S base models), 480dp is the largest
 * phones and an unfolded outer screen. Text at 200% is the largest Android allows.
 *
 * In A0 these images are recorded and published for review. From A1, when there are real
 * screens to protect, recorded images are committed as baselines and CI fails on any
 * unintended change.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FoundationScreenshotTest {

    private val capabilities = DeviceCapabilities.from(
        DeviceFacts(sdkInt = 36, isLowRamDevice = false, totalMemoryBytes = 8L shl 30, hasOnDeviceSpeechRecognizer = true),
    )

    private fun capture(name: String, palette: RemliPalette) {
        captureRoboImage("build/outputs/roborazzi/foundation_$name.png") {
            FoundationScreen(capabilities, palette)
        }
    }

    @Test
    @Config(qualifiers = SMALL)
    fun smallPhoneLight() = capture("small_light", RemliPalette.Light)

    @Test
    @Config(qualifiers = SMALL_NIGHT)
    fun smallPhoneDark() = capture("small_dark", RemliPalette.Dark)

    @Test
    @Config(qualifiers = MEDIUM)
    fun mediumPhoneLight() = capture("medium_light", RemliPalette.Light)

    @Test
    @Config(qualifiers = LARGE_NIGHT)
    fun largePhoneDark() = capture("large_dark", RemliPalette.Dark)

    @Test
    @Config(qualifiers = SMALL)
    fun smallPhoneLargestText() {
        RuntimeEnvironment.setFontScale(2.0f)
        capture("small_text200", RemliPalette.Light)
    }

    private companion object {
        const val SMALL = "w360dp-h640dp-xhdpi"
        const val MEDIUM = "w411dp-h891dp-xxhdpi"
        const val LARGE_NIGHT = "w480dp-h1040dp-night-xxhdpi"

        // Android's qualifier order puts night mode before density, and Robolectric rejects
        // anything out of order.
        const val SMALL_NIGHT = "w360dp-h640dp-night-xhdpi"
    }
}

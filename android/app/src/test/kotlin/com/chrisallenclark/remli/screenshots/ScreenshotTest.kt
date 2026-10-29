package com.chrisallenclark.remli.screenshots

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.capabilities.DeviceCapabilities
import com.chrisallenclark.remli.capabilities.DeviceFacts
import com.chrisallenclark.remli.design.Appearance
import com.chrisallenclark.remli.design.RemliTheme
import com.chrisallenclark.remli.design.palette
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.IdeaStatus
import com.chrisallenclark.remli.model.ImportanceLevel
import com.chrisallenclark.remli.model.Library
import com.chrisallenclark.remli.ui.CaptureSheet
import com.chrisallenclark.remli.ui.IdeaActions
import com.chrisallenclark.remli.ui.IdeaDetailScreen
import com.chrisallenclark.remli.ui.IdeasListScreen
import com.chrisallenclark.remli.ui.SettingsSheet
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Every A1 screen rendered on the JVM, across the screen sizes and settings Android phones
 * ship with: 360dp (small and budget phones), 411dp (the common size), 480dp (the largest
 * phones), light and dark, and text at 200%.
 *
 * These are the regression net: recorded images are committed under
 * src/test/screenshots, and CI fails when a screen changes without the baseline being
 * updated. Fidelity against iOS is judged from the emulator screenshots instead, which
 * include the real status bar and system fonts.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScreenshotTest {

    private val now = 1_800_000_000_000L
    private val minute = 60_000L

    private val ideas = listOf(
        Idea(
            id = "supper", createdAt = now - 2 * minute, updatedAt = now - 2 * minute,
            title = "Grandmother's supper club",
            text = "A pop-up supper club that only serves dishes from one grandmother's recipe book each month",
            pinned = true, importanceOverride = ImportanceLevel.Major.score, statusRaw = IdeaStatus.Active.raw,
        ),
        Idea(id = "vat", createdAt = now - 3 * minute, text = "Call the accountant about the quarterly VAT return"),
        Idea(id = "brew", createdAt = now - 26 * 60 * minute, text = "Weekend market stall selling cold brew in returnable glass bottles"),
    )
    private val library = Library(ideas = ideas)
    private val capabilities = DeviceCapabilities.from(DeviceFacts(36, false, 8L shl 30, true))

    private fun shot(name: String, dark: Boolean, content: @Composable () -> Unit) {
        captureRoboImage("build/outputs/roborazzi/$name.png") {
            RemliTheme(dark) {
                Box(Modifier.fillMaxSize().background(palette.canvas)) { content() }
            }
        }
    }

    @Composable
    private fun IdeasList(library: Library) = IdeasListScreen(
        library = library, isLoaded = true, now = now, topInset = 24.dp, bottomInset = 24.dp,
        onOpen = {}, onTogglePin = {}, onDelete = {}, state = rememberLazyListState(),
    )

    @Composable
    private fun Detail() = IdeaDetailScreen(
        idea = ideas.first(),
        actions = IdeaActions({}, {}, {}, {}, {}, {}, {}),
        onBack = {},
        bottomInset = 24.dp,
    )

    // Ideas

    @Test @Config(qualifiers = SMALL) fun ideasSmallLight() = shot("ideas_small_light", false) { IdeasList(library) }
    @Test @Config(qualifiers = MEDIUM) fun ideasMediumLight() = shot("ideas_medium_light", false) { IdeasList(library) }
    @Test @Config(qualifiers = MEDIUM_NIGHT) fun ideasMediumDark() = shot("ideas_medium_dark", true) { IdeasList(library) }
    @Test @Config(qualifiers = LARGE) fun ideasLargeLight() = shot("ideas_large_light", false) { IdeasList(library) }
    @Test @Config(qualifiers = MEDIUM) fun ideasEmptyLight() = shot("ideas_empty_light", false) { IdeasList(Library()) }
    @Test @Config(qualifiers = MEDIUM_NIGHT) fun ideasEmptyDark() = shot("ideas_empty_dark", true) { IdeasList(Library()) }

    @Test @Config(qualifiers = SMALL)
    fun ideasSmallText200() {
        RuntimeEnvironment.setFontScale(2.0f)
        shot("ideas_small_text200", false) { IdeasList(library) }
    }

    // Capture

    @Test @Config(qualifiers = MEDIUM) fun captureLight() = shot("capture_medium_light", false) { CaptureSheet({}, { _, _ -> }) }
    @Test @Config(qualifiers = MEDIUM_NIGHT) fun captureDark() = shot("capture_medium_dark", true) { CaptureSheet({}, { _, _ -> }) }

    // Detail

    @Test @Config(qualifiers = SMALL) fun detailSmallLight() = shot("detail_small_light", false) { Detail() }
    @Test @Config(qualifiers = MEDIUM) fun detailMediumLight() = shot("detail_medium_light", false) { Detail() }
    @Test @Config(qualifiers = MEDIUM_NIGHT) fun detailMediumDark() = shot("detail_medium_dark", true) { Detail() }

    @Test @Config(qualifiers = SMALL)
    fun detailSmallText200() {
        RuntimeEnvironment.setFontScale(2.0f)
        shot("detail_small_text200", false) { Detail() }
    }

    // Settings

    @Test @Config(qualifiers = MEDIUM)
    fun settingsLight() = shot("settings_medium_light", false) { SettingsSheet(Appearance.System, {}, capabilities, {}) }

    @Test @Config(qualifiers = MEDIUM_NIGHT)
    fun settingsDark() = shot("settings_medium_dark", true) { SettingsSheet(Appearance.Dark, {}, capabilities, {}) }

    private companion object {
        const val SMALL = "w360dp-h640dp-xhdpi"
        const val MEDIUM = "w411dp-h891dp-xxhdpi"
        const val MEDIUM_NIGHT = "w411dp-h891dp-night-xxhdpi"
        const val LARGE = "w480dp-h1040dp-xxhdpi"
    }
}

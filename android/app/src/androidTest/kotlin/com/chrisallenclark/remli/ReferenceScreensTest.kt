package com.chrisallenclark.remli

import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chrisallenclark.remli.design.Appearance
import com.chrisallenclark.remli.model.ImportanceLevel
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The same walk as android/tools/ios-reference/UITests/ReferenceScreens.swift, step for
 * step and with the same ideas, so each Android screenshot has an iOS counterpart with the
 * same name.
 */
@RunWith(AndroidJUnit4::class)
class ReferenceScreensTest {

    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    @Test fun light() = walk(Appearance.Light, "light")

    @Test fun dark() = walk(Appearance.Dark, "dark")

    private fun walk(appearance: Appearance, prefix: String) {
        rule.reset(appearance)
        rule.waitForTag("first-run")
        Shots.take("${prefix}_01_ideas_empty")

        rule.onNodeWithTag("capture-button").performClick()
        rule.waitForTag("capture-body")
        Shots.take("${prefix}_02_capture_empty")
        rule.onNodeWithText("Cancel").performClick()
        rule.waitForGone("capture-sheet")

        rule.capture("Weekend market stall selling cold brew in returnable glass bottles")
        rule.capture("Call the accountant about the quarterly VAT return")
        rule.capture(
            "A pop-up supper club that only serves dishes from one grandmother's recipe book each month",
            name = "Grandmother's supper club",
            beforeSave = { Shots.take("${prefix}_03_capture_typed") },
        )
        Shots.take("${prefix}_04_ideas_list")

        rule.onNodeWithText("Grandmother's supper club").performTouchInput { longClick() }
        rule.waitForText("Pin")
        Shots.take("${prefix}_05_context_menu")
        rule.onNode(hasText("Pin") and hasContentDescription("Pin")).performClick()
        rule.waitForGone("menu")
        Shots.take("${prefix}_06_ideas_pinned")

        rule.onNodeWithText("Grandmother's supper club").performClick()
        rule.waitForTag("idea-detail")
        Shots.take("${prefix}_07_detail")

        rule.onNodeWithContentDescription("${ImportanceLevel.Major.label}. ${ImportanceLevel.Major.effect}").performClick()
        rule.waitForText("You set this.")
        Shots.take("${prefix}_08_detail_importance_set")

        rule.onNodeWithTag("idea-detail").performTouchInput { swipeUp() }
        Shots.take("${prefix}_09_detail_scrolled")
        rule.onNodeWithTag("idea-detail").performTouchInput { androidx.compose.ui.test.swipeDown() }

        rule.onNodeWithTag("detail-menu").performClick()
        rule.waitForText("Edit")
        Shots.take("${prefix}_10_detail_menu")
        rule.onNodeWithText("Edit").performClick()
        rule.waitForTag("detail-title-field")
        Shots.take("${prefix}_11_detail_editing")
        rule.onNodeWithContentDescription("Back").performClick()
        rule.waitForTag("ideas-list")

        rule.onNodeWithTag("open-settings").performClick()
        rule.waitForTag("settings")
        Shots.take("${prefix}_12_settings")
    }
}

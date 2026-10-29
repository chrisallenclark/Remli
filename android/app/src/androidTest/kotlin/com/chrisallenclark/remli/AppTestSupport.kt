package com.chrisallenclark.remli

import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.AndroidComposeTestRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.platform.app.InstrumentationRegistry
import com.chrisallenclark.remli.design.Appearance
import kotlinx.coroutines.runBlocking

typealias AppRule = AndroidComposeTestRule<ActivityScenarioRule<MainActivity>, MainActivity>

val app: RemliApplication
    get() = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as RemliApplication

/** Every test starts from an empty library and the light appearance. */
fun AppRule.reset(appearance: Appearance = Appearance.Light) {
    runBlocking { app.store.clearAll().join() }
    runOnUiThread { app.appearance.set(appearance) }
    waitForIdle()
}

fun AppRule.waitForText(text: String, timeoutMs: Long = 5_000) =
    waitUntil(timeoutMs) { onAllNodes(hasText(text, substring = true)).fetchSemanticsNodes().isNotEmpty() }

fun AppRule.waitForTag(tag: String, timeoutMs: Long = 5_000) =
    waitUntil(timeoutMs) { onAllNodes(androidx.compose.ui.test.hasTestTag(tag)).fetchSemanticsNodes().isNotEmpty() }

fun AppRule.waitForGone(tag: String, timeoutMs: Long = 5_000) =
    waitUntil(timeoutMs) { onAllNodes(androidx.compose.ui.test.hasTestTag(tag)).fetchSemanticsNodes().isEmpty() }

/** Captures through the sheet, exactly as a person would. */
fun AppRule.capture(body: String, name: String? = null, beforeSave: () -> Unit = {}) {
    onNodeWithTag("capture-button").performClick()
    waitForTag("capture-body")
    onNodeWithTag("capture-body").performTextInput(body)
    if (name != null) onNodeWithTag("capture-name").performTextInput(name)
    beforeSave()
    onNodeWithTag("capture-save").performClick()
    waitForGone("capture-sheet")
    waitForText(name ?: body.take(20))
}

fun SemanticsNodeInteraction.tap() = performClick()

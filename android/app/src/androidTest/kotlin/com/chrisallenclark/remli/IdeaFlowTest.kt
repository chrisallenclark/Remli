package com.chrisallenclark.remli

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chrisallenclark.remli.data.RemliDatabase
import com.chrisallenclark.remli.design.Appearance
import com.chrisallenclark.remli.model.IdeaStatus
import com.chrisallenclark.remli.model.ImportanceLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The A1 features, end to end on a real Android build: what a person does, and what is on
 * disk afterwards. Runs on every emulator in the CI matrix.
 */
@RunWith(AndroidJUnit4::class)
class IdeaFlowTest {

    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    @Before fun start() = rule.reset()

    /** Reads the database file afresh, bypassing the running store entirely. */
    private fun onDisk() = RemliDatabase(InstrumentationRegistry.getInstrumentation().targetContext).use { it.readLibrary() }

    /** The first row's accessibility label, "Idea: <title>". */
    private fun firstRow(): String =
        rule.onAllNodesWithTag("idea-row").fetchSemanticsNodes().first()
            .config.getOrNull(SemanticsProperties.ContentDescription)?.firstOrNull().orEmpty()

    @Test fun firstRunShowsTheEmptyState() {
        rule.waitForTag("first-run")
        rule.onNodeWithText("Nothing captured yet").assertIsDisplayed()
        rule.onNodeWithTag("capture-button").assertIsDisplayed()
        rule.onNodeWithTag("tab-bar").assertIsDisplayed()
    }

    @Test fun captureSavesToDiskWithItsName() {
        rule.capture("A pop-up supper club that only serves dishes from one grandmother's recipe book", name = "Supper club")
        rule.onNodeWithText("Supper club").assertIsDisplayed()

        val saved = onDisk().ideas.single()
        assertEquals("Supper club", saved.title)
        assertTrue(saved.text.startsWith("A pop-up supper club"))
        assertEquals(IdeaStatus.Seed, saved.status)
    }

    @Test fun anUnnamedIdeaIsListedByItsFirstLine() {
        rule.capture("Weekend market stall selling cold brew")
        rule.onNodeWithText("Weekend market stall selling cold brew").assertIsDisplayed()
        assertEquals("", onDisk().ideas.single().title)
    }

    @Test fun saveDoesNothingUntilThereIsText() {
        rule.onNodeWithTag("capture-button").performClick()
        rule.waitForTag("capture-body")
        rule.onNodeWithTag("capture-name").performTextInput("Only a name")
        rule.onNodeWithTag("capture-save").performClick()
        rule.waitForIdle()
        rule.onNodeWithTag("capture-sheet").assertIsDisplayed()
        assertTrue(onDisk().ideas.isEmpty())
    }

    @Test fun cancelDiscardsTheDraft() {
        rule.onNodeWithTag("capture-button").performClick()
        rule.waitForTag("capture-body")
        rule.onNodeWithTag("capture-body").performTextInput("Never mind")
        rule.onNodeWithText("Cancel").performClick()
        rule.waitForGone("capture-sheet")
        assertTrue(onDisk().ideas.isEmpty())
    }

    @Test fun pinningFloatsAnIdeaToTheTop() {
        rule.capture("Older thought about tripods")
        rule.capture("Newer thought about lenses")
        // Newest first until something is pinned.
        assertTrue(firstRow().startsWith("Idea: Newer"))

        rule.onNodeWithText("Older thought about tripods").performTouchInput { longClick() }
        rule.waitForText("Pin")
        rule.onNode(hasText("Pin") and hasContentDescription("Pin")).performClick()
        rule.waitUntil(5_000) { onDisk().ideas.any { it.pinned } }

        rule.waitUntil(5_000) {
            firstRow().startsWith("Idea: Older")
        }
        assertTrue(onDisk().ideas.single { it.text.startsWith("Older") }.pinned)
    }

    @Test fun deleteFromTheListRemovesTheIdea() {
        rule.capture("Something to throw away")
        rule.onNodeWithText("Something to throw away").performTouchInput { longClick() }
        rule.waitForText("Delete")
        rule.onNode(hasText("Delete") and hasContentDescription("Delete")).performClick()
        rule.waitForTag("first-run")
        assertTrue(onDisk().ideas.isEmpty())
    }

    @Test fun anIdeaOpensEditsAndKeepsTheEdits() {
        rule.capture("Buy a tripod. The cheap one wobbles on carpet", name = "Tripod")
        rule.onNodeWithText("Tripod").performClick()
        rule.waitForTag("idea-detail")
        rule.onNodeWithTag("detail-body").assertIsDisplayed()

        // Tapping the name starts editing, as on iOS.
        rule.onNodeWithTag("detail-title").performClick()
        rule.waitForTag("detail-title-field")
        rule.onNodeWithTag("detail-title-field").performTextReplacement("  Filming kit  ")
        rule.onNodeWithTag("detail-body-field").performTextReplacement("Buy a tripod with rubber feet")
        rule.onNodeWithTag("detail-menu").performClick()
        rule.waitForText("Done editing")
        rule.onNodeWithText("Done editing").performClick()

        rule.waitUntil(5_000) { onDisk().ideas.single().title == "Filming kit" }
        val saved = onDisk().ideas.single()
        assertEquals("Filming kit", saved.title) // trimmed
        assertEquals("Buy a tripod with rubber feet", saved.text)

        rule.onNodeWithContentDescription("Back").performClick()
        rule.waitForTag("ideas-list")
        rule.onNodeWithText("Filming kit").assertIsDisplayed()
    }

    @Test fun leavingWhileEditingStillSaves() {
        rule.capture("Draft that will be changed")
        rule.onNodeWithText("Draft that will be changed").performClick()
        rule.waitForTag("idea-detail")
        rule.onNodeWithTag("detail-title").performClick()
        rule.waitForTag("detail-body-field")
        rule.onNodeWithTag("detail-body-field").performTextReplacement("Changed, then left by Back")
        rule.onNodeWithContentDescription("Back").performClick()
        rule.waitUntil(5_000) { onDisk().ideas.single().text == "Changed, then left by Back" }
    }

    @Test fun importanceAndStatusArePersisted() {
        rule.capture("Client tracking app for personal trainers", name = "Client tracker")
        rule.onNodeWithText("Client tracker").performClick()
        rule.waitForTag("importance")
        rule.onNodeWithText("Not judged yet — set it yourself, or wait for Remli to read it.").assertIsDisplayed()

        rule.onNodeWithContentDescription("${ImportanceLevel.Major.label}. ${ImportanceLevel.Major.effect}").performClick()
        rule.waitForText("You set this.")
        rule.onNodeWithContentDescription("Active").performClick()

        rule.waitUntil(5_000) { onDisk().ideas.single().status == IdeaStatus.Active }
        val saved = onDisk().ideas.single()
        assertEquals(ImportanceLevel.Major.score, saved.importanceOverride!!, 0.0)

        // Tapping the chosen level again hands it back to the guess.
        rule.onNodeWithContentDescription("${ImportanceLevel.Major.label}. ${ImportanceLevel.Major.effect}").performClick()
        rule.waitUntil(5_000) { onDisk().ideas.single().importanceOverride == null }
        assertNull(onDisk().ideas.single().importanceOverride)
    }

    @Test fun deleteFromTheDetailMenuReturnsToTheList() {
        rule.capture("Short-lived")
        rule.onNodeWithText("Short-lived").performClick()
        rule.waitForTag("idea-detail")
        rule.onNodeWithTag("detail-menu").performClick()
        rule.waitForText("Delete")
        rule.onNode(hasText("Delete") and hasContentDescription("Delete")).performClick()
        rule.waitForTag("first-run")
        assertTrue(onDisk().ideas.isEmpty())
    }

    @Test fun ideasSurviveTheActivityBeingRecreated() {
        rule.capture("Still here after a restart", name = "Survivor")
        rule.activityRule.scenario.recreate()
        rule.waitForText("Survivor")
        rule.onNodeWithText("Survivor").assertIsDisplayed()
    }

    @Test fun appearanceChoiceAppliesAndPersists() {
        rule.onNodeWithTag("open-settings").performClick()
        rule.waitForTag("settings")
        rule.onNodeWithContentDescription("Dark").performClick()
        rule.waitForIdle()
        assertEquals(Appearance.Dark, app.appearance.appearance)
        rule.onNodeWithText("Done").performClick()
        rule.waitForGone("settings")
        assertEquals("dark", InstrumentationRegistry.getInstrumentation().targetContext
            .getSharedPreferences("remli", 0).getString("remli.appearance", null))
    }
}

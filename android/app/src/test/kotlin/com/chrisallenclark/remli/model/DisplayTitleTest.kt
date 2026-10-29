package com.chrisallenclark.remli.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/** `Idea.displayTitle` and the change rules for the other edits, which iOS states in prose rather than tests. */
class DisplayTitleTest {

    @Test fun `an empty idea is Untitled`() = assertEquals("Untitled", Idea(text = "").displayTitle)

    @Test fun `blank leading lines are skipped`() = assertEquals("Second", Idea(text = "\n\nSecond\nThird").displayTitle)

    @Test fun `long first lines are cut at sixty characters with an ellipsis`() {
        val line = "x".repeat(80)
        assertEquals("x".repeat(60) + "…", Idea(text = line).displayTitle)
        assertEquals("x".repeat(60), Idea(text = "x".repeat(60)).displayTitle)
    }

    @Test fun `unchanged text and status are not changes`() {
        val i = Idea(text = "Same")
        assertSame(i, i.withText("Same"))
        assertSame(i, i.withStatus(IdeaStatus.Seed))
    }

    @Test fun `declaring a goal starts a seed, and only a seed`() {
        assertEquals(IdeaStatus.Active, Idea(text = "x").withGoalToggled().status)
        val parked = Idea(text = "x").copy(statusRaw = IdeaStatus.Parked.raw).withGoalToggled()
        assertEquals(IdeaStatus.Parked, parked.status)
    }

    @Test fun `unknown raw values fall back safely, as on iOS`() {
        val i = Idea(text = "x", kindRaw = "chore", statusRaw = "archived", captureModeRaw = "telepathy")
        assertEquals(IdeaKind.Idea, i.kind)
        assertEquals(IdeaStatus.Seed, i.status)
        assertEquals(CaptureMode.Text, i.captureMode)
    }

    @Test fun `raw values match what iOS stores`() {
        assertEquals(listOf("idea", "task"), IdeaKind.entries.map { it.raw })
        assertEquals(listOf("seed", "active", "parked", "done"), IdeaStatus.entries.map { it.raw })
        assertEquals(listOf("relatesTo", "buildsOn", "prerequisiteFor", "variantOf", "contradicts"), LinkKind.entries.map { it.raw })
    }
}

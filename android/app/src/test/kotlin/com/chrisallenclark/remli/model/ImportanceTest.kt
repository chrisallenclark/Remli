package com.chrisallenclark.remli.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Port of Tests/ImportanceTests.swift ("Importance" and "Idea naming" suites), case for case.
 *
 * Not yet ported, because the code they exercise does not exist on Android yet:
 * `resurfacingObeysYou` (A6) and `theMapObeysYou` plus the "Map node weighting" suite (A4).
 */
class ImportanceTest {

    private fun idea(text: String = "Client tracking app") = Idea(text = text)

    @Test fun `an un-corrected idea reports the model's guess`() {
        val i = idea().copy(importanceScore = 0.72)
        assertEquals(0.72, i.importance, 0.0)
        assertFalse(i.importanceIsUserSet)
    }

    @Test fun `a correction wins, and the guess survives underneath it`() {
        val i = idea().copy(importanceScore = 0.72).withImportance(ImportanceLevel.Passing)
        assertEquals(ImportanceLevel.Passing.score, i.importance, 0.0)
        assertTrue(i.importanceIsUserSet)
        assertEquals(0.72, i.importanceScore, 0.0)
        assertEquals(ImportanceLevel.Matters, i.importanceGuessLevel)
    }

    @Test fun `re-enrichment cannot undo a correction`() {
        val i = idea().copy(importanceScore = 0.72).withImportance(ImportanceLevel.Major)
            .copy(importanceScore = 0.20) // exactly what enrichment does on a later pass
        assertEquals(ImportanceLevel.Major.score, i.importance, 0.0)
    }

    @Test fun `clearing a correction returns to the guess`() {
        val i = idea().copy(importanceScore = 0.72)
            .withImportance(ImportanceLevel.Passing)
            .withImportance(null)
        assertEquals(0.72, i.importance, 0.0)
        assertFalse(i.importanceIsUserSet)
    }

    @Test fun `every level round-trips to itself`() {
        for (level in ImportanceLevel.entries) assertEquals(level, ImportanceLevel.nearest(level.score))
    }

    @Test fun `scores between levels land on the nearer one`() {
        assertEquals(ImportanceLevel.Passing, ImportanceLevel.nearest(0.0))
        assertEquals(ImportanceLevel.Major, ImportanceLevel.nearest(1.0))
        assertEquals(ImportanceLevel.Matters, ImportanceLevel.nearest(0.70))
        assertEquals(ImportanceLevel.WorthKeeping, ImportanceLevel.nearest(0.44))
    }

    // Idea naming

    private val tripods = "A long rambling thought about tripods"

    @Test fun `a name you set is kept, trimmed`() {
        val i = idea(tripods).withTitle("  Filming kit  ")
        assertEquals("Filming kit", i.title)
        assertEquals("Filming kit", i.displayTitle)
    }

    @Test fun `enrichment will not overwrite a name you set`() {
        var i = idea(tripods).withTitle("Filming kit")
        if (i.title.isEmpty()) i = i.copy(title = "Tripod Purchase Plan")
        assertEquals("Filming kit", i.title)
    }

    @Test fun `enrichment still names an idea you left alone`() {
        var i = idea(tripods)
        assertTrue(i.title.isEmpty())
        if (i.title.isEmpty()) i = i.copy(title = "Tripod Purchase Plan")
        assertEquals("Tripod Purchase Plan", i.displayTitle)
    }

    @Test fun `clearing the name falls back to the first line, not to Untitled`() {
        val i = idea("Buy a tripod\nThe cheap one wobbles on carpet").withTitle("Filming kit").withTitle("   ")
        assertTrue(i.title.isEmpty())
        assertEquals("Buy a tripod", i.displayTitle)
    }

    @Test fun `setting the same name again does not count as a change`() {
        val named = idea("Buy a tripod").withTitle("Filming kit", now = 1_000)
        val again = named.withTitle("Filming kit", now = 2_000)
        assertSame(named, again)
        assertEquals(1_000L, again.updatedAt)
    }

    @Test fun `naming an idea marks it as touched`() {
        val i = idea("Buy a tripod").copy(updatedAt = 0).withTitle("Filming kit", now = 5_000)
        assertTrue(i.updatedAt > 0)
    }
}

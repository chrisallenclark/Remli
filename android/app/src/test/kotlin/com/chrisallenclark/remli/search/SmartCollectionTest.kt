package com.chrisallenclark.remli.search

import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.IdeaCategory
import com.chrisallenclark.remli.model.IdeaKind
import com.chrisallenclark.remli.model.Library
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Port of Tests/SmartCollectionTests.swift, case for case. */
class SmartCollectionTest {

    private val business = IdeaCategory(name = "Business")
    private val mealPrep = IdeaCategory(name = "Meal Prep", parentId = business.id)
    private val health = IdeaCategory(name = "Health")
    private val categories = listOf(business, mealPrep, health)

    private fun idea(text: String, place: IdeaCategory? = null) = Idea(text = text, categoryId = place?.id)
    private fun lib(ideas: List<Idea>) = Library(ideas = ideas, categories = categories)

    @Test fun `selecting a Space includes the ideas inside its Collections`() {
        val nested = idea("Sunday batch cooking", mealPrep)
        val chip = SmartCollection.Category(business.id, "Business", isCollection = false)
        assertTrue(chip.matches(nested, lib(listOf(nested))))
    }

    @Test fun `selecting a Collection does not reach back up into its Space`() {
        val general = idea("Something general", business)
        val chip = SmartCollection.Category(mealPrep.id, "Meal Prep", isCollection = true)
        assertFalse(chip.matches(general, lib(listOf(general))))
    }

    @Test fun `an idea with no Space matches only All`() {
        val loose = idea("Unfiled thought")
        val library = lib(listOf(loose))
        assertTrue(SmartCollection.All.matches(loose, library))
        assertFalse(SmartCollection.Category("other", "Business", false).matches(loose, library))
    }

    @Test fun `each Space is followed immediately by its own Collections`() {
        val ideas = listOf(idea("Batch cooking", mealPrep), idea("Supplier list", mealPrep), idea("Marathon plan", health))
        val labels = SmartCollection.available(ideas, lib(ideas)).map { it.label }
        val b = labels.indexOf("Business")
        val m = labels.indexOf("Meal Prep")
        val h = labels.indexOf("Health")
        assertTrue(b >= 0 && m >= 0 && h >= 0)
        assertTrue(b < m)
        assertTrue(m < h)
    }

    @Test fun `a Space with no direct ideas still gets a chip`() {
        val ideas = listOf(idea("Batch cooking", mealPrep))
        val labels = SmartCollection.available(ideas, lib(ideas)).map { it.label }
        assertTrue("Business" in labels)
        assertTrue("Meal Prep" in labels)
    }

    @Test fun `a chip that would show nothing is never offered`() {
        val ideas = listOf(idea("Just a thought"))
        assertEquals(listOf("All"), SmartCollection.available(ideas, lib(ideas)).map { it.label })
    }

    @Test fun `to-dos get their own chip and ideas do not appear in it`() {
        val thought = idea("An idea worth keeping")
        val chore = idea("Call the dentist").copy(kindRaw = IdeaKind.Task.raw)
        val library = lib(listOf(thought, chore))
        assertTrue(SmartCollection.Tasks.matches(chore, library))
        assertFalse(SmartCollection.Tasks.matches(thought, library))
    }
}

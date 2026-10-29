package com.chrisallenclark.remli.model

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Port of the parts of Tests/StepVisibilityTests.swift that exist on Android yet: which ideas
 * are roadmap steps, and that listings drop them. The Space-count and roadmap cases follow
 * with those screens (A4/A5).
 */
class StepVisibilityTest {

    private val space = IdeaCategory(name = "Business", isUserOwned = true)
    private val goal = Idea(text = "Client tracking app for personal trainers", isEnriched = true, isGoal = true, categoryId = space.id)
    private val step = Idea(text = "Price three suppliers", kindRaw = IdeaKind.Task.raw, categoryId = space.id)
    private val chore = Idea(text = "Renew the gym insurance", kindRaw = IdeaKind.Task.raw, categoryId = space.id)
    private val link = IdeaLink(
        sourceId = step.id, targetId = goal.id, kindRaw = LinkKind.PrerequisiteFor.raw,
        rationale = "Needed before the build can start.", strength = 0.8, originRaw = LinkOrigin.User.raw,
    )
    private val library = Library(ideas = listOf(goal, step, chore), categories = listOf(space), links = listOf(link))

    @Test fun `a workshop step is recognised as a step`() {
        assertTrue(library.isRoadmapStep(step))
        assertFalse("a loose to-do is not a roadmap step", library.isRoadmapStep(chore))
        assertFalse("the goal is not its own step", library.isRoadmapStep(goal))
    }

    @Test fun `steps are dropped from an idea listing, to-dos are not`() {
        val listed = library.ideasExcludingSteps().map { it.id }
        assertTrue(goal.id in listed)
        assertTrue(chore.id in listed)
        assertFalse("a step leaked into an idea listing", step.id in listed)
    }

    @Test fun `a rejected link does not make a step`() {
        val rejected = library.copy(links = listOf(link.copy(reviewStateRaw = LinkReviewState.Rejected.raw)))
        assertFalse(rejected.isRoadmapStep(step))
    }
}

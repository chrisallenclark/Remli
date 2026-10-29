package com.chrisallenclark.remli.model

/**
 * Everything in the store at one moment: what SwiftData's object graph gives the iOS views
 * for free, as a plain snapshot. Relationship questions — which Space an idea is in, whether
 * it is a roadmap step — are answered here so every screen asks them the same way.
 */
data class Library(
    val ideas: List<Idea> = emptyList(),
    val categories: List<IdeaCategory> = emptyList(),
    val links: List<IdeaLink> = emptyList(),
) {
    private val categoriesById: Map<String, IdeaCategory> by lazy { categories.associateBy { it.id } }
    private val outgoing: Map<String, List<IdeaLink>> by lazy {
        links.filter { it.sourceId != null }.groupBy { it.sourceId!! }
    }

    fun idea(id: String): Idea? = ideas.firstOrNull { it.id == id }

    fun category(id: String?): IdeaCategory? = id?.let { categoriesById[it] }

    fun category(of idea: Idea): IdeaCategory? = category(idea.categoryId)

    fun parent(of category: IdeaCategory): IdeaCategory? = category(category.parentId)

    /**
     * A to-do that exists as a step towards something else. Belongs on its roadmap only.
     * Derived, as on iOS, so detaching a step turns it back into an ordinary to-do.
     */
    fun isRoadmapStep(idea: Idea): Boolean {
        if (idea.kind != IdeaKind.Task) return false
        return outgoing[idea.id].orEmpty().any { it.isActive && it.kind == LinkKind.PrerequisiteFor }
    }

    /** Everything except roadmap steps. Every screen that lists or counts ideas uses this. */
    fun ideasExcludingSteps(): List<Idea> = ideas.filterNot(::isRoadmapStep)
}

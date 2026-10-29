package com.chrisallenclark.remli.search

import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.IdeaKind
import com.chrisallenclark.remli.model.IdeaStatus
import com.chrisallenclark.remli.model.Library

/**
 * The filter chips above the ideas list. Port of SmartCollection.swift — same chips, same
 * order, same rule that a chip which would be empty is never offered.
 */
sealed interface SmartCollection {
    val key: String
    val label: String
    val symbol: Symbol

    data object All : SmartCollection {
        override val key = "all"; override val label = "All"; override val symbol = Symbol.SquareStack
    }

    data object QuickWins : SmartCollection {
        override val key = "quick"; override val label = "Quick wins"; override val symbol = Symbol.Bolt
    }

    data object InProgress : SmartCollection {
        override val key = "progress"; override val label = "In progress"; override val symbol = Symbol.CircleLeftHalfFilled
    }

    data object Tasks : SmartCollection {
        override val key = "tasks"; override val label = "To-dos"; override val symbol = Symbol.CheckmarkCircle
    }

    data class Category(val id: String, val name: String, val isCollection: Boolean) : SmartCollection {
        override val key get() = "cat.$id"
        override val label get() = name
        // A Collection chip sits right after its Space's, so the distinct glyph stops them
        // reading as peers.
        override val symbol get() = if (isCollection) Symbol.ArrowTurnDownRight else Symbol.SquareStack3dUp
    }

    fun matches(idea: Idea, library: Library): Boolean = when (this) {
        All -> true
        QuickWins -> idea.kind == IdeaKind.Idea &&
            idea.status != IdeaStatus.Done &&
            idea.estimatedMinutes in 1..QUICK_WIN_MINUTES
        InProgress -> idea.status == IdeaStatus.Active
        Tasks -> idea.kind == IdeaKind.Task && idea.status != IdeaStatus.Done
        is Category -> {
            val category = library.categoryOf(idea)
            when {
                category == null -> false
                category.id == id -> true
                // A Space shows everything underneath it; a Collection only itself.
                else -> !isCollection && category.parentId == id
            }
        }
    }

    companion object {
        /** Anything achievable in a sitting. */
        const val QUICK_WIN_MINUTES = 30

        /** Builds the visible set from what is actually there. */
        fun available(ideas: List<Idea>, library: Library): List<SmartCollection> {
            val result = mutableListOf<SmartCollection>(All)
            for (candidate in listOf(InProgress, QuickWins, Tasks)) {
                if (ideas.any { candidate.matches(it, library) }) result += candidate
            }

            data class Tally(val id: String, val name: String, val parentId: String?, var total: Int)

            val counts = linkedMapOf<String, Tally>()
            for (idea in ideas) {
                val category = library.categoryOf(idea) ?: continue
                counts.getOrPut(category.id) { Tally(category.id, category.name, category.parentId, 0) }.total += 1
                val parent = library.parentOf(category)
                if (parent != null) {
                    counts.getOrPut(parent.id) { Tally(parent.id, parent.name, null, 0) }.total += 1
                }
            }

            // By how much is in them, then by name — Swift's `<` on String, which is a
            // plain code-point comparison, as Kotlin's compareTo is.
            fun ordered(tallies: List<Tally>) =
                tallies.sortedWith(compareByDescending<Tally> { it.total }.thenBy { it.name })

            for (root in ordered(counts.values.filter { it.parentId == null })) {
                result += Category(root.id, root.name, isCollection = false)
                for (child in ordered(counts.values.filter { it.parentId == root.id })) {
                    result += Category(child.id, child.name, isCollection = true)
                }
            }
            return result
        }
    }
}

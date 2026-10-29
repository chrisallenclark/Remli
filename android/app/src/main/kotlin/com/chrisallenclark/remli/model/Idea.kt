package com.chrisallenclark.remli.model

import java.util.UUID

/**
 * A captured thought. Port of Sources/Shared/Models/Idea.swift.
 *
 * Every field iOS stores is stored here under the same name, including ones no Android
 * screen uses yet, so the two libraries stay structurally identical and a later sync, or
 * a later feature, never needs a migration to catch up.
 *
 * Immutable: a change produces a new value. The `with…` functions carry the iOS rules about
 * what counts as a change and when an idea is "touched" — `updatedAt` drives how brightly an
 * idea burns on the map, so touching it when nothing changed would be a visible lie.
 */
data class Idea(
    val id: String = UUID.randomUUID().toString(),
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = createdAt,

    val title: String = "",
    val text: String = "",
    /** For voice captures, the untouched transcript. The audio itself is never retained. */
    val transcriptRaw: String? = null,

    val kindRaw: String = IdeaKind.Idea.raw,
    val statusRaw: String = IdeaStatus.Seed.raw,
    val captureModeRaw: String = CaptureMode.Text.raw,

    val tags: List<String> = emptyList(),
    /** The model's guess, 0–1. Never the last word. */
    val importanceScore: Double = 0.0,
    /** Your correction to that guess. Null means you have not weighed in. */
    val importanceOverride: Double? = null,
    val estimatedMinutes: Int = 0,

    val pinned: Boolean = false,
    val isGoal: Boolean = false,
    val stepOrder: Int = 0,
    val dismissedSuggestions: List<String> = emptyList(),

    val remindAt: Long? = null,
    val lastSurfacedAt: Long? = null,
    val surfaceCount: Int = 0,

    val isEnriched: Boolean = false,
    val enrichmentAttempts: Int = 0,
    val linkedAt: Long? = null,
    val linkAttempts: Int = 0,

    /** The Space or Collection this lives in. */
    val categoryId: String? = null,
) {
    val kind: IdeaKind get() = IdeaKind.from(kindRaw)
    val status: IdeaStatus get() = IdeaStatus.from(statusRaw)
    val captureMode: CaptureMode get() = CaptureMode.from(captureModeRaw)

    /** A heading that always has something sensible in it, as on iOS. */
    val displayTitle: String
        get() {
            if (title.isNotEmpty()) return title
            val firstLine = text.split("\n").firstOrNull { it.isNotEmpty() }?.trim().orEmpty()
            if (firstLine.isEmpty()) return "Untitled"
            return if (firstLine.length <= 60) firstLine else firstLine.take(60) + "…"
        }

    /** Yours if you said, the model's otherwise. Everything that ranks ideas reads this. */
    val importance: Double get() = importanceOverride ?: importanceScore
    val importanceIsUserSet: Boolean get() = importanceOverride != null
    val importanceLevel: ImportanceLevel get() = ImportanceLevel.nearest(importance)
    val importanceGuessLevel: ImportanceLevel get() = ImportanceLevel.nearest(importanceScore)

    fun touched(now: Long = System.currentTimeMillis()) = copy(updatedAt = now)

    /** Sets your level, or clears back to the model's guess when passed null. */
    fun withImportance(level: ImportanceLevel?, now: Long = System.currentTimeMillis()) =
        copy(importanceOverride = level?.score).touched(now)

    /**
     * Names the idea yourself. Trimmed; setting the name it already has is not a change and
     * does not touch the idea. Clearing it hands naming back to [displayTitle].
     */
    fun withTitle(newTitle: String, now: Long = System.currentTimeMillis()): Idea {
        val trimmed = newTitle.trim()
        if (trimmed == title) return this
        return copy(title = trimmed).touched(now)
    }

    fun withText(newText: String, now: Long = System.currentTimeMillis()): Idea =
        if (newText == text) this else copy(text = newText).touched(now)

    fun withPinToggled(now: Long = System.currentTimeMillis()) = copy(pinned = !pinned).touched(now)

    fun withStatus(newStatus: IdeaStatus, now: Long = System.currentTimeMillis()): Idea =
        if (newStatus == status) this else copy(statusRaw = newStatus.raw).touched(now)

    /** Declaring a goal also starts a seed, exactly as the iOS menu does. */
    fun withGoalToggled(now: Long = System.currentTimeMillis()): Idea {
        val goal = !isGoal
        val nextStatus = if (goal && status == IdeaStatus.Seed) IdeaStatus.Active.raw else statusRaw
        return copy(isGoal = goal, statusRaw = nextStatus).touched(now)
    }

    companion object {
        /** A new capture. Written first, thought about later — see CaptureSheet. */
        fun captured(
            text: String,
            name: String = "",
            captureMode: CaptureMode = CaptureMode.Text,
            transcriptRaw: String? = null,
            now: Long = System.currentTimeMillis(),
        ) = Idea(
            createdAt = now,
            updatedAt = now,
            text = text,
            title = name.trim(),
            captureModeRaw = captureMode.raw,
            transcriptRaw = transcriptRaw,
        )
    }
}

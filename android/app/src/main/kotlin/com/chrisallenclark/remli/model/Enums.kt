package com.chrisallenclark.remli.model

// Port of Sources/Shared/Models/Enums.swift.
//
// Enumerations are persisted as raw strings, exactly as on iOS: adding or renaming a case,
// or reading a value written by a newer build, never trips a migration. Each model exposes
// a typed property over the stored string, falling back to a safe default.

/** Ideas get the full treatment; tasks skip enrichment and just carry a date. */
enum class IdeaKind(val raw: String, val label: String) {
    Idea("idea", "Idea"),
    Task("task", "To-do");

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: Idea
    }
}

/** Where an idea is in its life. Drives resurfacing and how the idea is drawn on the map. */
enum class IdeaStatus(val raw: String, val label: String) {
    Seed("seed", "Seed"),
    Active("active", "Active"),
    Parked("parked", "Parked"),
    Done("done", "Done");

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: Seed
    }
}

enum class CaptureMode(val raw: String) {
    Text("text"),
    Voice("voice");

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: Text
    }
}

/** Who proposed a connection. A link you drew yourself is never up for review. */
enum class LinkOrigin(val raw: String) {
    Ai("ai"),
    User("user");

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: Ai
    }
}

/** `Rejected` is kept rather than deleted so the same pair is never proposed again. */
enum class LinkReviewState(val raw: String) {
    Pending("pending"),
    Accepted("accepted"),
    Rejected("rejected");

    companion object {
        // Defaults to accepted, as on iOS: links that predate review were created silently.
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: Accepted
    }
}

/** The type of an edge between two ideas. Raw values match iOS exactly. */
enum class LinkKind(val raw: String, val label: String, val isDirected: Boolean) {
    RelatesTo("relatesTo", "Relates to", false),
    BuildsOn("buildsOn", "Builds on", true),
    PrerequisiteFor("prerequisiteFor", "Unlocks", true),
    VariantOf("variantOf", "Variant of", false),
    Contradicts("contradicts", "Tension with", false);

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: RelatesTo
    }
}

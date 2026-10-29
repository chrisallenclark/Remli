package com.chrisallenclark.remli.model

import kotlin.math.abs

/**
 * How much an idea matters, as a person would say it. Port of ImportanceLevel.swift —
 * scores, names and effects are identical.
 */
enum class ImportanceLevel(val raw: String, val score: Double, val label: String, val effect: String) {
    Passing("passing", 0.15, "Passing", "Kept, but Remli will stop bringing it up."),
    WorthKeeping("worthKeeping", 0.40, "Worth keeping", "Comes back occasionally."),
    Matters("matters", 0.65, "Matters", "Comes back regularly, and sits large on the map."),
    Major("major", 0.90, "Major", "Near the front of every review.");

    companion object {
        /**
         * The level a raw score falls into. Nearest by distance; ties fall to the lower
         * level, the conservative direction — `minBy` keeps the first minimum, as Swift's
         * `min(by:)` does.
         */
        fun nearest(score: Double): ImportanceLevel = entries.minBy { abs(it.score - score) }
    }
}

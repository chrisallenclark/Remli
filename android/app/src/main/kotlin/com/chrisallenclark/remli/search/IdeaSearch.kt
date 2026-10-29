package com.chrisallenclark.remli.search

import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.Library
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Search that understands meaning as well as spelling. Port of IdeaSearch.swift, scores and
 * thresholds unchanged.
 *
 * Both signals run and the better one wins per result. On Android the meaning signal has no
 * input until on-device embeddings arrive in A3 — documents carry no vector and the query
 * vector is null — so search is literal-only for now, exactly as iOS behaves on a device
 * with no embedding model.
 */
object IdeaSearch {

    data class Hit(val id: String, val score: Double, val isLiteral: Boolean, val reason: MatchReason)

    /** Why a result matched, so a result that shares none of your words can explain itself. */
    enum class MatchReason(val label: String, val symbol: Symbol) {
        Title("in the title", Symbol.MagnifyingGlass),
        Body("found in the text", Symbol.MagnifyingGlass),
        Tag("matched a tag", Symbol.MagnifyingGlass),
        Space("in this Space", Symbol.SquareStack3dUp),
        Meaning("similar in meaning", Symbol.MagnifyingGlass),
    }

    /** Below this, a semantic match is noise rather than a result. */
    private const val SEMANTIC_FLOOR = 0.62

    data class Document(
        val id: String,
        val title: String,
        val text: String,
        val tags: List<String> = emptyList(),
        val categoryName: String? = null,
        val embedding: FloatArray? = null,
    ) {
        companion object {
            fun of(idea: Idea, library: Library) = Document(
                id = idea.id,
                title = idea.displayTitle,
                text = idea.text,
                tags = idea.tags,
                categoryName = library.categoryOf(idea)?.name,
            )
        }
    }

    fun rank(query: String, documents: List<Document>, queryVector: FloatArray?): List<Hit> {
        val trimmed = query.trim().lowercase()
        if (trimmed.isEmpty()) return emptyList()

        val hits = documents.mapNotNull { document ->
            val (literal, literalReason) = literalScore(trimmed, document)

            var semantic = 0.0
            val embedding = document.embedding
            if (queryVector != null && embedding != null && embedding.isNotEmpty()) {
                val similarity = cosine(queryVector, embedding)
                if (similarity >= SEMANTIC_FLOOR) semantic = (similarity - SEMANTIC_FLOOR) / (1 - SEMANTIC_FLOOR)
            }

            // Best-of rather than a blend; an exact title match is never dragged down.
            val weightedSemantic = semantic * 0.85
            val score = max(literal, weightedSemantic)
            if (score <= 0.05) return@mapNotNull null

            val reason = if (literal >= weightedSemantic) (literalReason ?: MatchReason.Body) else MatchReason.Meaning
            Hit(document.id, score, isLiteral = literal > 0, reason = reason)
        }

        return hits.sortedWith(compareByDescending<Hit> { it.score }.thenBy { it.id })
    }

    /** Weighted by where the match landed. A hit in the title means more than one in the body. */
    private fun literalScore(query: String, document: Document): Pair<Double, MatchReason?> {
        val title = document.title.lowercase()
        val body = document.text.lowercase()

        if (title == query) return 1.0 to MatchReason.Title
        if (title.startsWith(query)) return 0.95 to MatchReason.Title
        if (title.contains(query)) return 0.85 to MatchReason.Title

        val category = document.categoryName?.lowercase()
        if (category != null && category.contains(query)) return 0.7 to MatchReason.Space

        if (document.tags.any { it.lowercase().contains(query) }) return 0.68 to MatchReason.Tag

        if (body.contains(query)) return 0.6 to MatchReason.Body

        // Every word present somewhere, in any order.
        val words = query.split(" ").filter { it.length > 2 }
        if (words.size > 1) {
            val haystack = "$title $body"
            if (words.all { haystack.contains(it) }) return 0.55 to MatchReason.Body
        }
        return 0.0 to null
    }

    /** Port of Similarity.cosine: cosine similarity mapped from −1…1 to 0…1, in doubles as on iOS. */
    fun cosine(a: FloatArray, b: FloatArray): Double {
        if (a.isEmpty() || a.size != b.size) return 0.0
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for (i in a.indices) {
            val x = a[i].toDouble()
            val y = b[i].toDouble()
            dot += x * y
            normA += x * x
            normB += y * y
        }
        if (normA <= 0 || normB <= 0) return 0.0
        return (dot / (sqrt(normA) * sqrt(normB)) + 1) / 2
    }
}

package com.chrisallenclark.remli.search

import com.chrisallenclark.remli.search.IdeaSearch.Document
import com.chrisallenclark.remli.search.IdeaSearch.MatchReason
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

/** Port of Tests/IdeaSearchTests.swift, case for case. */
class IdeaSearchTest {

    private fun document(title: String, text: String, tags: List<String> = emptyList(), space: String? = null, embedding: FloatArray? = null) =
        Document(UUID.randomUUID().toString(), title, text, tags, space, embedding)

    @Test fun `an exact title match ranks first and says so`() {
        val target = document("Client tracking app", "For personal trainers")
        val other = document("Something else entirely", "Client tracking gets a mention here")
        val hits = IdeaSearch.rank("Client tracking app", listOf(other, target), null)
        assertEquals(target.id, hits.first().id)
        assertEquals(MatchReason.Title, hits.first().reason)
        assertTrue(hits.first().isLiteral)
    }

    @Test fun `a match in the body is reported as a body match, not a title one`() {
        val hits = IdeaSearch.rank("packaging", listOf(document("Untitled", "An idea about packaging for the meal prep business")), null)
        assertEquals(1, hits.size)
        assertEquals(MatchReason.Body, hits.first().reason)
    }

    @Test fun `a tag match is reported as a tag match`() {
        val hits = IdeaSearch.rank("bartending", listOf(document("Cocktail bar", "Weddings and events", tags = listOf("bartending"))), null)
        assertEquals(MatchReason.Tag, hits.first().reason)
    }

    @Test fun `a Space name match is reported as a Space match`() {
        val hits = IdeaSearch.rank("macrova", listOf(document("Supplier list", "Nothing relevant", space = "Macrova")), null)
        assertEquals(MatchReason.Space, hits.first().reason)
    }

    @Test fun `a purely semantic hit is labelled as meaning, not invented word overlap`() {
        val vector = floatArrayOf(1f, 0f, 0f, 0f)
        val doc = document("Helping coaches find people to work with", "Nothing here uses the query's words at all", embedding = vector)
        val hits = IdeaSearch.rank("client acquisition", listOf(doc), vector)
        assertEquals(1, hits.size)
        assertEquals(MatchReason.Meaning, hits.first().reason)
        assertFalse(hits.first().isLiteral)
    }

    @Test fun `meaning never outranks an exact title match`() {
        val vector = floatArrayOf(1f, 0f, 0f, 0f)
        val exact = document("Meal prep", "Unrelated body", embedding = floatArrayOf(0f, 1f, 0f, 0f))
        val similar = document("Totally different", "Also different", embedding = vector)
        val hits = IdeaSearch.rank("Meal prep", listOf(similar, exact), vector)
        assertEquals(exact.id, hits.first().id)
        assertEquals(MatchReason.Title, hits.first().reason)
    }

    @Test fun `every word present in any order still matches`() {
        val hits = IdeaSearch.rank("coffee shop app", listOf(document("Untitled", "An app for finding quiet coffee shops to work in")), null)
        assertEquals(1, hits.size)
    }

    @Test fun `an empty query returns nothing rather than everything`() {
        val doc = document("Anything", "At all")
        assertTrue(IdeaSearch.rank("", listOf(doc), null).isEmpty())
        assertTrue(IdeaSearch.rank("   ", listOf(doc), null).isEmpty())
    }

    @Test fun `search still works with no vectors at all`() {
        val hits = IdeaSearch.rank("trainers", listOf(document("Client tracking app", "For trainers")), null)
        assertEquals(1, hits.size)
        assertEquals(MatchReason.Body, hits.first().reason)
    }

    @Test fun `results are ordered by score, best first`() {
        val strong = document("Packaging", "x")
        val weak = document("Unrelated", "a note that mentions packaging in passing")
        val hits = IdeaSearch.rank("packaging", listOf(weak, strong), null)
        assertEquals(2, hits.size)
        assertEquals(strong.id, hits[0].id)
        assertTrue(hits[0].score > hits[1].score)
    }
}

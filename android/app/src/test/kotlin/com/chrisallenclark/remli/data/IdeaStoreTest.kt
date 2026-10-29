package com.chrisallenclark.remli.data

import androidx.test.core.app.ApplicationProvider
import com.chrisallenclark.remli.model.IdeaLink
import com.chrisallenclark.remli.model.IdeaStatus
import com.chrisallenclark.remli.model.ImportanceLevel
import com.chrisallenclark.remli.model.LinkKind
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * The store against a real SQLite database: what is saved is what comes back, after the
 * database is closed and reopened — the closest a JVM test gets to killing the app.
 */
@RunWith(RobolectricTestRunner::class)
class IdeaStoreTest {

    private val context get() = ApplicationProvider.getApplicationContext<android.content.Context>()
    private lateinit var db: RemliDatabase
    private lateinit var store: IdeaStore

    private fun Job.await() = runBlocking { join() }

    @Before fun open() {
        context.deleteDatabase(NAME)
        db = RemliDatabase(context, NAME)
        store = IdeaStore(db)
        store.load().await()
    }

    @After fun close() = db.close()

    /** Closes everything and opens a fresh store on the same file. */
    private fun reopen(): IdeaStore {
        db.close()
        db = RemliDatabase(context, NAME)
        return IdeaStore(db).also { it.load().await() }
    }

    @Test fun `a capture is saved and survives reopening`() {
        val (id, job) = store.capture("  A pop-up supper club  ", name = " Supper club ")
        job.await()

        val saved = reopen().library.value.idea(id)!!
        assertEquals("A pop-up supper club", saved.text)
        assertEquals("Supper club", saved.title)
        assertEquals(IdeaStatus.Seed, saved.status)
        assertFalse(saved.isEnriched)
    }

    @Test fun `newest ideas come first`() {
        store.capture("First").second.await()
        Thread.sleep(5)
        store.capture("Second").second.await()
        assertEquals(listOf("Second", "First"), store.library.value.ideas.map { it.text })
    }

    @Test fun `edits persist, and an edit that changes nothing writes nothing`() {
        val (id, job) = store.capture("Buy a tripod")
        job.await()
        val before = store.library.value.idea(id)!!

        store.setTitle(id, "   ").await() // trims to the empty title it already has: no change
        assertEquals(before.updatedAt, store.library.value.idea(id)!!.updatedAt)

        store.setText(id, "Buy a tripod\nThe cheap one wobbles").await()
        store.setTitle(id, "  Filming kit ").await()
        store.togglePin(id).await()
        store.setImportance(id, ImportanceLevel.Major).await()
        store.setStatus(id, IdeaStatus.Active).await()

        val after = reopen().library.value.idea(id)!!
        assertEquals("Buy a tripod\nThe cheap one wobbles", after.text)
        assertEquals("Filming kit", after.title)
        assertTrue(after.pinned)
        assertEquals(ImportanceLevel.Major, after.importanceLevel)
        assertTrue(after.importanceIsUserSet)
        assertEquals(IdeaStatus.Active, after.status)
        assertTrue(after.updatedAt >= before.updatedAt)
    }

    @Test fun `clearing importance returns to the guess`() {
        val (id, job) = store.capture("x")
        job.await()
        store.setImportance(id, ImportanceLevel.Passing).await()
        store.setImportance(id, null).await()
        assertNull(reopen().library.value.idea(id)!!.importanceOverride)
    }

    @Test fun `deleting an idea removes it and its links, and nothing else`() {
        val (a, ja) = store.capture("A"); ja.await()
        val (b, jb) = store.capture("B"); jb.await()
        db.upsert(IdeaLink(sourceId = a, targetId = b, kindRaw = LinkKind.BuildsOn.raw, rationale = "Because."))
        store.load().await()
        assertEquals(1, store.library.value.links.size)

        store.delete(a).await()
        val library = reopen().library.value
        assertNull(library.idea(a))
        assertEquals("B", library.idea(b)!!.text)
        assertTrue("the link cascaded with its idea", library.links.isEmpty())
    }

    @Test fun `editing an idea keeps its links`() {
        val (a, ja) = store.capture("A"); ja.await()
        val (b, jb) = store.capture("B"); jb.await()
        db.upsert(IdeaLink(sourceId = a, targetId = b, rationale = "Because."))
        store.setText(a, "A, rewritten").await()
        assertEquals(1, reopen().library.value.links.size)
    }

    @Test fun `unreadable stored lists become empty rather than crashing`() {
        assertEquals(emptyList<String>(), decodeStrings("not json"))
        assertEquals(listOf("a", "b"), decodeStrings(encodeStrings(listOf("a", "b"))))
    }

    private companion object {
        const val NAME = "remli-test.db"
    }
}

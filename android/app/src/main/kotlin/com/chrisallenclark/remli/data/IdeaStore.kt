package com.chrisallenclark.remli.data

import com.chrisallenclark.remli.model.CaptureMode
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.ImportanceLevel
import com.chrisallenclark.remli.model.IdeaStatus
import com.chrisallenclark.remli.model.Library
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * The library, observed. Plays the part SwiftData's `@Query` and model context play on iOS:
 * screens read [library] and call the methods here to change it.
 *
 * **Every write goes to disk before anything else happens.** That is the guarantee iOS makes
 * about capture — the idea is saved the instant you stop, and nothing afterwards can cost
 * it — and it holds here because each write is committed to SQLite on a single serial
 * writer before the snapshot updates.
 *
 * Writes are fire-and-forget from the UI's point of view and strictly ordered: typing into
 * an idea and then deleting it can never land the other way round. Each returns its [Job] so
 * tests can wait for it.
 */
class IdeaStore(
    private val database: RemliDatabase,
    ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    private val writer = ioDispatcher.limitedParallelism(1)
    private val scope = CoroutineScope(SupervisorJob() + writer)

    private val state = MutableStateFlow(Library())
    val library: StateFlow<Library> = state.asStateFlow()

    /** Set once the first read from disk has finished, so screens never flash the empty state. */
    private val loadedState = MutableStateFlow(false)
    val isLoaded: StateFlow<Boolean> = loadedState.asStateFlow()

    fun load(): Job = scope.launch { reload(); loadedState.value = true }

    private fun reload() {
        state.value = database.readLibrary()
    }

    /** Saves a new capture. Returns the id it was saved under. */
    fun capture(text: String, name: String = "", mode: CaptureMode = CaptureMode.Text, transcriptRaw: String? = null): Pair<String, Job> {
        val idea = Idea.captured(text = text.trim(), name = name, captureMode = mode, transcriptRaw = transcriptRaw)
        val job = scope.launch {
            database.upsert(idea)
            reload()
        }
        return idea.id to job
    }

    /** Applies a change to one idea and saves it — only if it actually changed. */
    fun edit(id: String, change: (Idea) -> Idea): Job = scope.launch {
        val current = database.readIdea(id) ?: return@launch
        val next = change(current)
        if (next == current) return@launch
        database.update(next)
        reload()
    }

    fun setTitle(id: String, title: String) = edit(id) { it.withTitle(title) }
    fun setText(id: String, text: String) = edit(id) { it.withText(text) }
    fun togglePin(id: String) = edit(id) { it.withPinToggled() }
    fun toggleGoal(id: String) = edit(id) { it.withGoalToggled() }
    fun setStatus(id: String, status: IdeaStatus) = edit(id) { it.withStatus(status) }
    fun setImportance(id: String, level: ImportanceLevel?) = edit(id) { it.withImportance(level) }

    /** Empties the library. For tests only — nothing in the app deletes everything. */
    @androidx.annotation.VisibleForTesting
    fun clearAll(): Job = scope.launch {
        database.clearAll()
        reload()
        loadedState.value = true
    }

    fun delete(id: String): Job = scope.launch {
        database.deleteIdea(id)
        reload()
    }
}

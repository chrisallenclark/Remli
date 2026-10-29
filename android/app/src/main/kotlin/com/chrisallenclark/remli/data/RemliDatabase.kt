package com.chrisallenclark.remli.data

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.IdeaCategory
import com.chrisallenclark.remli.model.IdeaLink
import org.json.JSONArray

/**
 * The on-device store. Plays the part of RemliSchema.swift and SwiftData.
 *
 * Plain SQLite rather than Room: no annotation processor in a build that can only be run in
 * CI, and the schema is three tables. Columns carry the iOS property names, so the two
 * libraries can be compared field by field and a future sync maps one-to-one.
 *
 * The iOS rules for a schema that survives change are kept: every column has a default,
 * enumerations are raw strings, and there are no uniqueness constraints beyond the id.
 * Deletes follow the iOS relationship rules — an idea's links go with it (cascade); a
 * Space's ideas and Collections stay, unfiled (nullify).
 */
class RemliDatabase(context: Context, name: String? = NAME) :
    SQLiteOpenHelper(context, name, null, VERSION) {

    override fun onConfigure(db: SQLiteDatabase) {
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE category (
                id TEXT PRIMARY KEY NOT NULL,
                createdAt INTEGER NOT NULL DEFAULT 0,
                name TEXT NOT NULL DEFAULT '',
                colorHex TEXT NOT NULL DEFAULT 'BC976A',
                colorIsUserSet INTEGER NOT NULL DEFAULT 0,
                symbolIsUserSet INTEGER NOT NULL DEFAULT 0,
                symbolName TEXT NOT NULL DEFAULT 'lightbulb',
                parentId TEXT REFERENCES category(id) ON DELETE SET NULL,
                isUserOwned INTEGER NOT NULL DEFAULT 0,
                coverImageData BLOB,
                coverPresetID TEXT
            )
            """,
        )
        db.execSQL(
            """
            CREATE TABLE idea (
                id TEXT PRIMARY KEY NOT NULL,
                createdAt INTEGER NOT NULL DEFAULT 0,
                updatedAt INTEGER NOT NULL DEFAULT 0,
                title TEXT NOT NULL DEFAULT '',
                text TEXT NOT NULL DEFAULT '',
                transcriptRaw TEXT,
                kindRaw TEXT NOT NULL DEFAULT 'idea',
                statusRaw TEXT NOT NULL DEFAULT 'seed',
                captureModeRaw TEXT NOT NULL DEFAULT 'text',
                tags TEXT NOT NULL DEFAULT '[]',
                importanceScore REAL NOT NULL DEFAULT 0,
                importanceOverride REAL,
                estimatedMinutes INTEGER NOT NULL DEFAULT 0,
                pinned INTEGER NOT NULL DEFAULT 0,
                isGoal INTEGER NOT NULL DEFAULT 0,
                stepOrder INTEGER NOT NULL DEFAULT 0,
                dismissedSuggestions TEXT NOT NULL DEFAULT '[]',
                remindAt INTEGER,
                lastSurfacedAt INTEGER,
                surfaceCount INTEGER NOT NULL DEFAULT 0,
                isEnriched INTEGER NOT NULL DEFAULT 0,
                enrichmentAttempts INTEGER NOT NULL DEFAULT 0,
                embedding BLOB,
                linkedAt INTEGER,
                linkAttempts INTEGER NOT NULL DEFAULT 0,
                categoryId TEXT REFERENCES category(id) ON DELETE SET NULL
            )
            """,
        )
        db.execSQL(
            """
            CREATE TABLE link (
                id TEXT PRIMARY KEY NOT NULL,
                createdAt INTEGER NOT NULL DEFAULT 0,
                kindRaw TEXT NOT NULL DEFAULT 'relatesTo',
                rationale TEXT NOT NULL DEFAULT '',
                strength REAL NOT NULL DEFAULT 0,
                confirmedByUser INTEGER NOT NULL DEFAULT 0,
                confidence REAL NOT NULL DEFAULT 1,
                originRaw TEXT NOT NULL DEFAULT 'ai',
                reviewStateRaw TEXT NOT NULL DEFAULT 'accepted',
                sourceId TEXT REFERENCES idea(id) ON DELETE CASCADE,
                targetId TEXT REFERENCES idea(id) ON DELETE CASCADE
            )
            """,
        )
        db.execSQL("CREATE INDEX idea_createdAt ON idea(createdAt)")
        db.execSQL("CREATE INDEX link_source ON link(sourceId)")
        db.execSQL("CREATE INDEX link_target ON link(targetId)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Version 1 is the first schema. Each later version adds a numbered step here; a
        // migration never drops a table holding someone's ideas.
    }

    // MARK: - Reading

    fun readLibrary(): com.chrisallenclark.remli.model.Library {
        val db = readableDatabase
        return com.chrisallenclark.remli.model.Library(
            ideas = db.rawQuery("SELECT * FROM idea ORDER BY createdAt DESC", null).use { c -> c.map(::readIdea) },
            categories = db.rawQuery("SELECT * FROM category", null).use { c -> c.map(::readCategory) },
            links = db.rawQuery("SELECT * FROM link", null).use { c -> c.map(::readLink) },
        )
    }

    fun readIdea(id: String): Idea? =
        readableDatabase.rawQuery("SELECT * FROM idea WHERE id = ?", arrayOf(id)).use { c -> c.map(::readIdea).firstOrNull() }

    // MARK: - Writing

    fun upsert(idea: Idea) {
        writableDatabase.insertWithOnConflict("idea", null, idea.toValues(), SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun upsert(category: IdeaCategory) {
        writableDatabase.insertWithOnConflict("category", null, category.toValues(), SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun upsert(link: IdeaLink) {
        writableDatabase.insertWithOnConflict("link", null, link.toValues(), SQLiteDatabase.CONFLICT_REPLACE)
    }

    /**
     * Updates an existing idea in place. Not REPLACE: a replace is a delete then an insert,
     * and the delete would cascade through the idea's links.
     */
    fun update(idea: Idea) {
        writableDatabase.update("idea", idea.toValues(), "id = ?", arrayOf(idea.id))
    }

    fun clearAll() {
        writableDatabase.apply {
            delete("link", null, null)
            delete("idea", null, null)
            delete("category", null, null)
        }
    }

    fun deleteIdea(id: String) {
        writableDatabase.delete("idea", "id = ?", arrayOf(id))
    }

    companion object {
        const val NAME = "remli.db"
        const val VERSION = 1
    }
}

// MARK: - Row mapping

private inline fun <T> Cursor.map(read: (Cursor) -> T): List<T> {
    val out = ArrayList<T>(count)
    while (moveToNext()) out += read(this)
    return out
}

private fun Cursor.str(col: String): String = getString(getColumnIndexOrThrow(col)) ?: ""
private fun Cursor.strOrNull(col: String): String? = getColumnIndexOrThrow(col).let { if (isNull(it)) null else getString(it) }
private fun Cursor.long(col: String): Long = getLong(getColumnIndexOrThrow(col))
private fun Cursor.longOrNull(col: String): Long? = getColumnIndexOrThrow(col).let { if (isNull(it)) null else getLong(it) }
private fun Cursor.int(col: String): Int = getInt(getColumnIndexOrThrow(col))
private fun Cursor.bool(col: String): Boolean = getInt(getColumnIndexOrThrow(col)) != 0
private fun Cursor.double(col: String): Double = getDouble(getColumnIndexOrThrow(col))
private fun Cursor.doubleOrNull(col: String): Double? = getColumnIndexOrThrow(col).let { if (isNull(it)) null else getDouble(it) }
private fun Cursor.strings(col: String): List<String> = decodeStrings(str(col))

/** String lists are stored as JSON arrays. Anything unreadable becomes an empty list rather than a crash. */
internal fun decodeStrings(json: String): List<String> = runCatching {
    val array = JSONArray(json)
    List(array.length()) { array.getString(it) }
}.getOrDefault(emptyList())

internal fun encodeStrings(values: List<String>): String = JSONArray(values).toString()

private fun readIdea(c: Cursor) = Idea(
    id = c.str("id"),
    createdAt = c.long("createdAt"),
    updatedAt = c.long("updatedAt"),
    title = c.str("title"),
    text = c.str("text"),
    transcriptRaw = c.strOrNull("transcriptRaw"),
    kindRaw = c.str("kindRaw"),
    statusRaw = c.str("statusRaw"),
    captureModeRaw = c.str("captureModeRaw"),
    tags = c.strings("tags"),
    importanceScore = c.double("importanceScore"),
    importanceOverride = c.doubleOrNull("importanceOverride"),
    estimatedMinutes = c.int("estimatedMinutes"),
    pinned = c.bool("pinned"),
    isGoal = c.bool("isGoal"),
    stepOrder = c.int("stepOrder"),
    dismissedSuggestions = c.strings("dismissedSuggestions"),
    remindAt = c.longOrNull("remindAt"),
    lastSurfacedAt = c.longOrNull("lastSurfacedAt"),
    surfaceCount = c.int("surfaceCount"),
    isEnriched = c.bool("isEnriched"),
    enrichmentAttempts = c.int("enrichmentAttempts"),
    linkedAt = c.longOrNull("linkedAt"),
    linkAttempts = c.int("linkAttempts"),
    categoryId = c.strOrNull("categoryId"),
)

private fun readCategory(c: Cursor) = IdeaCategory(
    id = c.str("id"),
    createdAt = c.long("createdAt"),
    name = c.str("name"),
    colorHex = c.str("colorHex"),
    colorIsUserSet = c.bool("colorIsUserSet"),
    symbolIsUserSet = c.bool("symbolIsUserSet"),
    symbolName = c.str("symbolName"),
    parentId = c.strOrNull("parentId"),
    isUserOwned = c.bool("isUserOwned"),
    coverPresetID = c.strOrNull("coverPresetID"),
)

private fun readLink(c: Cursor) = IdeaLink(
    id = c.str("id"),
    createdAt = c.long("createdAt"),
    kindRaw = c.str("kindRaw"),
    rationale = c.str("rationale"),
    strength = c.double("strength"),
    confirmedByUser = c.bool("confirmedByUser"),
    confidence = c.double("confidence"),
    originRaw = c.str("originRaw"),
    reviewStateRaw = c.str("reviewStateRaw"),
    sourceId = c.strOrNull("sourceId"),
    targetId = c.strOrNull("targetId"),
)

/** The embedding column is owned by the connection engine (A3) and deliberately not written here. */
private fun Idea.toValues() = ContentValues().apply {
    put("id", id)
    put("createdAt", createdAt)
    put("updatedAt", updatedAt)
    put("title", title)
    put("text", text)
    put("transcriptRaw", transcriptRaw)
    put("kindRaw", kindRaw)
    put("statusRaw", statusRaw)
    put("captureModeRaw", captureModeRaw)
    put("tags", encodeStrings(tags))
    put("importanceScore", importanceScore)
    put("importanceOverride", importanceOverride)
    put("estimatedMinutes", estimatedMinutes)
    put("pinned", pinned)
    put("isGoal", isGoal)
    put("stepOrder", stepOrder)
    put("dismissedSuggestions", encodeStrings(dismissedSuggestions))
    put("remindAt", remindAt)
    put("lastSurfacedAt", lastSurfacedAt)
    put("surfaceCount", surfaceCount)
    put("isEnriched", isEnriched)
    put("enrichmentAttempts", enrichmentAttempts)
    put("linkedAt", linkedAt)
    put("linkAttempts", linkAttempts)
    put("categoryId", categoryId)
}

private fun IdeaCategory.toValues() = ContentValues().apply {
    put("id", id)
    put("createdAt", createdAt)
    put("name", name)
    put("colorHex", colorHex)
    put("colorIsUserSet", colorIsUserSet)
    put("symbolIsUserSet", symbolIsUserSet)
    put("symbolName", symbolName)
    put("parentId", parentId)
    put("isUserOwned", isUserOwned)
    put("coverPresetID", coverPresetID)
}

private fun IdeaLink.toValues() = ContentValues().apply {
    put("id", id)
    put("createdAt", createdAt)
    put("kindRaw", kindRaw)
    put("rationale", rationale)
    put("strength", strength)
    put("confirmedByUser", confirmedByUser)
    put("confidence", confidence)
    put("originRaw", originRaw)
    put("reviewStateRaw", reviewStateRaw)
    put("sourceId", sourceId)
    put("targetId", targetId)
}

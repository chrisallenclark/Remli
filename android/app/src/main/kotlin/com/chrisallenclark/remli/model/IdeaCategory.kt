package com.chrisallenclark.remli.model

import java.util.UUID

/**
 * A Space — or, one level down, a Collection inside one. Port of IdeaCategory.swift.
 *
 * Stored here so the schema matches iOS from the first build. The Space screens, palette
 * and icon pickers arrive in A3/A5; until then the only reader is the Ideas list's chips.
 */
data class IdeaCategory(
    val id: String = UUID.randomUUID().toString(),
    val createdAt: Long = System.currentTimeMillis(),
    val name: String = "",
    /** Six-digit RRGGBB, no leading hash. */
    val colorHex: String = "BC976A",
    val colorIsUserSet: Boolean = false,
    val symbolIsUserSet: Boolean = false,
    /** An SF Symbol name, as iOS stores it. Android maps it to a drawable for display. */
    val symbolName: String = "lightbulb",
    /** Null means this *is* a Space. */
    val parentId: String? = null,
    val isUserOwned: Boolean = false,
    val coverPresetID: String? = null,
) {
    val isSpace: Boolean get() = parentId == null
    val isCollection: Boolean get() = parentId != null
}

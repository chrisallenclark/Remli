package com.chrisallenclark.remli.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.input.ImeAction
import com.chrisallenclark.remli.design.ContextMenuOverlay
import com.chrisallenclark.remli.design.pressable
import com.chrisallenclark.remli.search.IdeaSearch
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.design.Chip
import com.chrisallenclark.remli.design.MenuItem
import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.design.SymbolIcon
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.palette
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.Library
import com.chrisallenclark.remli.search.SmartCollection

/**
 * Everything you have thought. Port of IdeasListView.swift.
 *
 * Not yet here, and tracked in PARITY.md: search (A7), the "Enter <Space>" card (A5).
 */
@Composable
fun IdeasListScreen(
    library: Library,
    isLoaded: Boolean,
    now: Long,
    topInset: Dp,
    bottomInset: Dp,
    onOpen: (Idea) -> Unit,
    onTogglePin: (Idea) -> Unit,
    onDelete: (Idea) -> Unit,
    state: LazyListState,
) {
    val listable = remember(library) { library.ideasExcludingSteps() }
    val collections = remember(library) { SmartCollection.available(listable, library) }
    var selectedKey by rememberSaveable { mutableStateOf(SmartCollection.All.key) }
    val selected = collections.firstOrNull { it.key == selectedKey } ?: SmartCollection.All
    var query by rememberSaveable { mutableStateOf("") }

    val hits = remember(query, listable, library) {
        if (query.isBlank()) emptyList()
        else IdeaSearch.rank(query, listable.map { IdeaSearch.Document.of(it, library) }, queryVector = null)
    }
    val reasons = remember(hits) { hits.associate { it.id to it.reason } }

    // Search results in rank order; otherwise pinned ideas float to the top, then newest first.
    val visible = remember(listable, selected, library, hits, query) {
        if (query.isNotBlank()) {
            val byId = listable.associateBy { it.id }
            hits.mapNotNull { byId[it.id] }
        } else {
            listable.filter { selected.matches(it, library) }
                .sortedWith(compareByDescending<Idea> { it.pinned }.thenByDescending { it.createdAt })
        }
    }

    if (library.ideas.isEmpty()) {
        Column(Modifier.fillMaxSize().padding(top = topInset)) {
            com.chrisallenclark.remli.design.LargeTitle("Ideas")
            SearchField(query, onQuery = { query = it })
            // Nothing until the first read finishes, so a full library never flashes empty.
            if (isLoaded) FirstRunView(Modifier.weight(1f).padding(bottom = bottomInset))
        }
        return
    }

    LazyColumn(
        state = state,
        modifier = Modifier.fillMaxSize().testTag("ideas-list"),
        contentPadding = PaddingValues(top = topInset, bottom = bottomInset + Theme.Space.md),
        verticalArrangement = Arrangement.spacedBy(Theme.Space.sm),
    ) {
        item(key = "title") { com.chrisallenclark.remli.design.LargeTitle("Ideas") }
        item(key = "search") { SearchField(query, onQuery = { query = it }) }

        if (query.isBlank() && collections.size > 1) {
            item(key = "chips") {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = Theme.Space.md),
                    horizontalArrangement = Arrangement.spacedBy(Theme.Space.xs),
                ) {
                    items(collections, key = { it.key }) { collection ->
                        Chip(collection.label, collection.symbol, collection == selected, onClick = { selectedKey = collection.key })
                    }
                }
            }
        }

        if (visible.isEmpty()) {
            item(key = "none") { NoResultsView(query, selected) }
        } else {
            items(visible, key = { it.id }) { idea ->
                IdeaListItem(
                    idea = idea,
                    library = library,
                    now = now,
                    reason = reasons[idea.id],
                    onOpen = { onOpen(idea) },
                    onTogglePin = { onTogglePin(idea) },
                    onDelete = { onDelete(idea) },
                    modifier = Modifier.animateItem(fadeInSpec = null, fadeOutSpec = null, placementSpec = Theme.Motion.standard()),
                )
            }
        }
    }
}

/** A row, with the long-press menu iOS gives it as a `.contextMenu`. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun IdeaListItem(
    idea: Idea,
    library: Library,
    now: Long,
    reason: IdeaSearch.MatchReason?,
    onOpen: () -> Unit,
    onTogglePin: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var menu by remember { mutableStateOf(false) }
    var bounds by remember { mutableStateOf(Rect.Zero) }
    val haptics = LocalHapticFeedback.current
    val category = library.categoryOf(idea)
    Column(modifier.padding(horizontal = Theme.Space.md), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        IdeaRow(
            idea = idea,
            category = category,
            now = now,
            modifier = Modifier
                .onGloballyPositioned { bounds = it.boundsInWindow() }
                .graphicsLayer { alpha = if (menu) 0f else 1f }
                .semantics { contentDescription = "Idea: ${idea.displayTitle}" }
                .testTag("idea-row")
                .combinedClickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = onOpen,
                    onLongClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        menu = true
                    },
                ),
        )
        // Only while searching: a result should say how it was found.
        if (reason != null) MatchReasonLabel(reason)
    }
    ContextMenuOverlay(
        expanded = menu,
        anchor = bounds,
        onDismiss = { menu = false },
        items = listOf(
            MenuItem(if (idea.pinned) "Unpin" else "Pin", if (idea.pinned) Symbol.PinSlash else Symbol.Pin, action = onTogglePin),
            MenuItem("Delete", Symbol.Trash, destructive = true, action = onDelete),
        ),
    ) { IdeaRow(idea = idea, category = category, now = now) }
}

@Composable
private fun MatchReasonLabel(reason: IdeaSearch.MatchReason) {
    Txt(reason.label, Theme.Typography.meta, palette.inkMuted, Modifier.padding(start = Theme.Space.xs, bottom = Theme.Space.xxs))
}

/** iOS's search field: a recessed capsule with a magnifier, under the large title. */
@Composable
private fun SearchField(query: String, onQuery: (String) -> Unit) {
    val p = palette
    val fill = if (p.isDark) Color(0x3D767680) else Color(0x1F767680)
    Row(
        Modifier
            .padding(horizontal = Theme.Space.md)
            .fillMaxWidth()
            .height(36.dp)
            .background(fill, CircleShape)
            .padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SymbolIcon(Symbol.MagnifyingGlass, p.inkMuted, 15.dp)
        Box(Modifier.weight(1f)) {
            if (query.isEmpty()) Txt("Search your ideas", Theme.Typography.body, p.inkMuted, maxLines = 1)
            BasicTextField(
                value = query,
                onValueChange = onQuery,
                singleLine = true,
                textStyle = Theme.Typography.body.copy(color = p.ink),
                cursorBrush = SolidColor(p.ember),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                modifier = Modifier.fillMaxWidth().testTag("search"),
            )
        }
        if (query.isNotEmpty()) {
            SymbolIcon(Symbol.XmarkCircleFill, p.inkMuted, 15.dp, Modifier.pressable(label = "Clear search") { onQuery("") })
        }
    }
}

@Composable
private fun NoResultsView(query: String, collection: SmartCollection) {
    val p = palette
    Column(
        Modifier.fillMaxWidth().padding(top = Theme.Space.xl, start = Theme.Space.lg, end = Theme.Space.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Theme.Space.xs),
    ) {
        Txt(if (query.isBlank()) "Nothing in ${collection.label} yet" else "No matches", Theme.Typography.title, p.ink, textAlign = TextAlign.Center)
        if (query.isNotBlank()) {
            // iOS says Remli also searches by meaning; on Android that arrives with A3, so
            // the hint is about words only until then.
            Txt("Try a word from the idea itself.", Theme.Typography.meta, p.inkMuted, textAlign = TextAlign.Center)
        }
    }
}

/**
 * The zero state. Spaces are emergent, so on day one there is genuinely nothing to show,
 * and this says what will happen rather than inventing sample content.
 */
@Composable
private fun FirstRunView(modifier: Modifier = Modifier) {
    val p = palette
    Column(
        modifier.fillMaxWidth().padding(horizontal = Theme.Space.lg).testTag("first-run"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Theme.Space.md, Alignment.CenterVertically),
    ) {
        SymbolIcon(Symbol.LightbulbMax, p.ember, 40.dp)
        Txt("Nothing captured yet", Theme.Typography.title, p.ink, textAlign = TextAlign.Center)
        Txt(
            "Tap Capture the next time something occurs to you.\nRemli will title it, file it, and start finding\nthe threads between your ideas.",
            Theme.Typography.meta.copy(lineHeight = Theme.Typography.meta.lineHeight * 1.2f),
            p.inkMuted,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(Theme.Space.xxl))
    }
}

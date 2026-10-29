package com.chrisallenclark.remli.ui

import androidx.compose.foundation.ExperimentalFoundationApi
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
import com.chrisallenclark.remli.design.IosMenu
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

    // Pinned ideas float to the top of every collection, then newest first.
    val visible = remember(listable, selected, library) {
        listable.filter { selected.matches(it, library) }
            .sortedWith(compareByDescending<Idea> { it.pinned }.thenByDescending { it.createdAt })
    }

    if (library.ideas.isEmpty()) {
        Column(Modifier.fillMaxSize().padding(top = topInset)) {
            com.chrisallenclark.remli.design.LargeTitle("Ideas")
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

        if (collections.size > 1) {
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
            item(key = "none") {
                Txt(
                    "Nothing in ${selected.label} yet",
                    Theme.Typography.title,
                    palette.ink,
                    Modifier.fillMaxWidth().padding(top = Theme.Space.xl),
                    textAlign = TextAlign.Center,
                )
            }
        } else {
            items(visible, key = { it.id }) { idea ->
                IdeaListItem(
                    idea = idea,
                    library = library,
                    now = now,
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
    onOpen: () -> Unit,
    onTogglePin: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var menu by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    Box(modifier.padding(horizontal = Theme.Space.md)) {
        IdeaRow(
            idea = idea,
            category = library.category(of = idea),
            now = now,
            modifier = Modifier
                .graphicsLayer { val s = if (menu) 1.02f else 1f; scaleX = s; scaleY = s }
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
        IosMenu(
            expanded = menu,
            onDismiss = { menu = false },
            items = listOf(
                MenuItem(if (idea.pinned) "Unpin" else "Pin", if (idea.pinned) Symbol.PinSlash else Symbol.Pin, action = onTogglePin),
                MenuItem("Delete", Symbol.Trash, destructive = true, action = onDelete),
            ),
        )
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

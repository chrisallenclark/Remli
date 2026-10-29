package com.chrisallenclark.remli.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.design.Chrome
import com.chrisallenclark.remli.design.GlassIconButton
import com.chrisallenclark.remli.design.InlineNavBar
import com.chrisallenclark.remli.design.IosMenu
import com.chrisallenclark.remli.design.MenuItem
import com.chrisallenclark.remli.design.SectionLabel
import com.chrisallenclark.remli.design.SegmentedControl
import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.cardBackground
import com.chrisallenclark.remli.design.palette
import com.chrisallenclark.remli.design.pressable
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.IdeaKind
import com.chrisallenclark.remli.model.IdeaStatus
import com.chrisallenclark.remli.model.ImportanceLevel
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** What the detail screen can ask the store to do. */
class IdeaActions(
    val setTitle: (String) -> Unit,
    val setText: (String) -> Unit,
    val togglePin: () -> Unit,
    val toggleGoal: () -> Unit,
    val setStatus: (IdeaStatus) -> Unit,
    val setImportance: (ImportanceLevel?) -> Unit,
    val delete: () -> Unit,
)

/**
 * One idea, read and edited. Port of IdeaDetailView.swift.
 *
 * Not yet here, and tracked in PARITY.md: the Space chip and "Move to a Space…" (A5),
 * "Work on this" (A4), connections (A4) and the roadmap preview (A4).
 */
@Composable
fun IdeaDetailScreen(
    idea: Idea,
    actions: IdeaActions,
    onBack: () -> Unit,
    bottomInset: Dp,
) {
    val p = palette
    var isEditing by rememberSaveable(idea.id) { mutableStateOf(false) }
    var titleDraft by rememberSaveable(idea.id) { mutableStateOf(idea.title) }
    var textDraft by rememberSaveable(idea.id) { mutableStateOf(idea.text) }
    var menu by remember { mutableStateOf(false) }
    val latest by rememberUpdatedState(actions)

    fun beginEditing() {
        titleDraft = idea.title
        textDraft = idea.text
        isEditing = true
    }

    /** Leaving edit mode tidies the name; an empty result hands naming back to the first line. */
    fun endEditing() {
        latest.setText(textDraft)
        latest.setTitle(titleDraft)
        isEditing = false
    }

    // The body saves as you type, a moment after you pause — iOS writes through on every
    // keystroke; this batches them without ever holding a change back for long.
    LaunchedEffect(textDraft, isEditing) {
        if (!isEditing) return@LaunchedEffect
        delay(350)
        latest.setText(textDraft)
    }
    // Leaving the screen counts as finishing, so nothing typed is ever lost.
    DisposableEffect(idea.id) {
        onDispose { if (isEditing) { latest.setText(textDraft); latest.setTitle(titleDraft) } }
    }
    BackHandler(enabled = isEditing) { endEditing(); onBack() }

    Box(Modifier.fillMaxSize().background(p.canvas).testTag("idea-detail")) {
        Column(
            Modifier
                .fillMaxSize()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Theme.Space.lg)
                .padding(top = topBarInset() + Theme.Space.md, bottom = bottomInset + Theme.Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Theme.Space.lg),
        ) {
            // Header
            Column(verticalArrangement = Arrangement.spacedBy(Theme.Space.xs)) {
                if (isEditing) {
                    Box {
                        if (titleDraft.isEmpty()) Txt("Name this idea", Theme.Typography.display, p.inkMuted)
                        BasicTextField(
                            value = titleDraft,
                            onValueChange = { titleDraft = it },
                            textStyle = Theme.Typography.display.copy(color = p.ink),
                            cursorBrush = SolidColor(p.ember),
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                            modifier = Modifier.fillMaxWidth().testTag("detail-title-field"),
                        )
                    }
                } else {
                    // Tapping the thing you want to change is the first thing anyone tries.
                    Txt(
                        idea.displayTitle,
                        Theme.Typography.display,
                        p.ink,
                        Modifier.testTag("detail-title").pressable(label = "Edit name") { beginEditing() },
                    )
                }
                Txt(detailDate(idea.createdAt), Theme.Typography.meta, p.inkMuted)
            }

            // Body
            if (isEditing) {
                BasicTextField(
                    value = textDraft,
                    onValueChange = { textDraft = it },
                    textStyle = Theme.Typography.ideaBody.copy(color = p.ink),
                    cursorBrush = SolidColor(p.ember),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth().heightIn(min = 220.dp).cardBackground().testTag("detail-body-field"),
                )
            } else {
                SelectionContainer {
                    Txt(
                        idea.text,
                        Theme.Typography.ideaBody.copy(lineHeight = Theme.Typography.ideaBody.lineHeight * 1.23f),
                        p.ink,
                        Modifier.fillMaxWidth().testTag("detail-body"),
                    )
                }
            }

            if (idea.tags.isNotEmpty()) TagRow(idea.tags)

            if (idea.kind == IdeaKind.Idea) {
                ImportanceControl(idea, onSet = actions.setImportance)
            }

            Column(verticalArrangement = Arrangement.spacedBy(Theme.Space.xs)) {
                SectionLabel("Status")
                SegmentedControl(
                    options = IdeaStatus.entries,
                    selected = idea.status,
                    label = { it.label },
                    onSelect = actions.setStatus,
                    modifier = Modifier.testTag("status"),
                )
            }
            Spacer(Modifier.height(Theme.Space.xxl))
        }

        InlineNavBar(
            title = "",
            leading = { GlassIconButton(Symbol.ChevronLeft, "Back", onClick = { if (isEditing) endEditing(); onBack() }) },
            trailing = {
                Box {
                    GlassIconButton(Symbol.EllipsisCircle, "More", onClick = { menu = true }, modifier = Modifier.testTag("detail-menu"))
                    IosMenu(
                        expanded = menu,
                        onDismiss = { menu = false },
                        items = listOf(
                            MenuItem(if (isEditing) "Done editing" else "Edit", Symbol.Pencil) {
                                if (isEditing) endEditing() else beginEditing()
                            },
                            MenuItem(if (idea.pinned) "Unpin" else "Pin", if (idea.pinned) Symbol.PinSlash else Symbol.Pin, action = actions.togglePin),
                            MenuItem(
                                if (idea.isGoal) "Stop pursuing this" else "I'm pursuing this",
                                if (idea.isGoal) Symbol.FlagSlash else Symbol.Flag,
                                action = actions.toggleGoal,
                            ),
                            MenuItem("Delete", Symbol.Trash, destructive = true, dividerBefore = true) {
                                isEditing = false
                                actions.delete()
                            },
                        ),
                    )
                }
            },
        )
    }
}

/** The status bar plus the inline bar: where content starts beneath the floating controls. */
@Composable
fun topBarInset(): Dp =
    WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + Chrome.barHeight

/**
 * `.dateTime.day().month(.abbreviated).hour().minute()` — "Oct 29 at 9:04 PM" in English,
 * as on iOS, and the locale's own pattern elsewhere. Follows the phone's 12/24-hour setting.
 */
@Composable
private fun detailDate(time: Long): String {
    val context = androidx.compose.ui.platform.LocalContext.current
    val locale = Locale.getDefault()
    val hour = if (android.text.format.DateFormat.is24HourFormat(context)) "Hmm" else "hmma"
    val date = SimpleDateFormat(android.text.format.DateFormat.getBestDateTimePattern(locale, "MMMd"), locale).format(Date(time))
    val clock = SimpleDateFormat(android.text.format.DateFormat.getBestDateTimePattern(locale, hour), locale).format(Date(time))
    return if (locale.language == "en") "$date at $clock"
    else SimpleDateFormat(android.text.format.DateFormat.getBestDateTimePattern(locale, "MMMd$hour"), locale).format(Date(time))
}

/** A row of tags. Port of TagRow. */
@Composable
fun TagRow(tags: List<String>) {
    val p = palette
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(Theme.Space.xs),
    ) {
        tags.forEach { tag ->
            Txt(tag, Theme.Typography.meta, p.inkMuted, Modifier.background(p.hairline, CircleShape).padding(horizontal = Theme.Space.xs, vertical = 3.dp))
        }
    }
}

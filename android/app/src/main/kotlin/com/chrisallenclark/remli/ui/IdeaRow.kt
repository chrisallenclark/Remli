package com.chrisallenclark.remli.ui

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.design.SymbolIcon
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.cardBackground
import com.chrisallenclark.remli.design.palette
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.IdeaCategory
import com.chrisallenclark.remli.model.IdeaKind

/** One idea in the list. Port of IdeaRowView.swift. */
@Composable
fun IdeaRow(idea: Idea, category: IdeaCategory?, now: Long, modifier: Modifier = Modifier) {
    val p = palette
    Column(
        modifier.fillMaxWidth().cardBackground(),
        verticalArrangement = Arrangement.spacedBy(Theme.Space.xs),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Txt(idea.displayTitle, Theme.Typography.ideaBody, p.ink, Modifier.weight(1f), maxLines = 2)
            if (idea.pinned) {
                Spacer(Modifier.width(Theme.Space.xs))
                SymbolIcon(Symbol.PinFill, p.ember, 11.dp, Modifier.padding(top = 4.dp))
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Theme.Space.xs)) {
            if (category != null) {
                CategoryChip(category)
            }
            // iOS shows "Filing…" here while enrichment is pending. Android has no
            // enrichment until A3, so the label would never resolve and is not shown.
            if (idea.kind == IdeaKind.Task) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                    SymbolIcon(Symbol.CheckmarkCircle, p.inkMuted, 11.dp)
                    Txt(IdeaKind.Task.label, Theme.Typography.meta, p.inkMuted)
                }
            }
            Spacer(Modifier.weight(1f))
            Txt(relativeDate(idea.createdAt, now), Theme.Typography.meta, p.inkMuted, maxLines = 1)
        }
    }
}

/**
 * `Text(date, format: .relative(presentation: .named))` — "now", "1 second ago",
 * "2 minutes ago", "yesterday", matching the iOS reference screens.
 */
fun relativeDate(time: Long, now: Long): String =
    if (now - time < DateUtils.SECOND_IN_MILLIS) "now"
    else DateUtils.getRelativeTimeSpanString(time, now, DateUtils.SECOND_IN_MILLIS).toString()

/** A Space's name in its own colour. Port of CategoryChip. */
@Composable
fun CategoryChip(category: IdeaCategory, displayPath: String? = null) {
    val accent = hexColor(category.colorHex) ?: palette.ember
    Row(
        Modifier.background(accent.copy(alpha = 0.12f), CircleShape).padding(horizontal = Theme.Space.xs, vertical = 3.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SymbolIcon(Symbol.forSfName(category.symbolName), accent, 10.dp)
        Txt(displayPath ?: category.name, Theme.Typography.meta, accent, maxLines = 1)
    }
}

/** Parses RRGGBB. Null rather than a default, so callers choose the fallback. */
fun hexColor(hex: String): Color? {
    val cleaned = hex.removePrefix("#")
    if (cleaned.length != 6) return null
    val value = cleaned.toLongOrNull(16) ?: return null
    return Color(0xFF000000 or value)
}

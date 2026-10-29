package com.chrisallenclark.remli.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chrisallenclark.remli.design.ContinuousShape
import com.chrisallenclark.remli.design.Hairline
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.cardBackground
import com.chrisallenclark.remli.design.palette
import com.chrisallenclark.remli.design.pressable
import com.chrisallenclark.remli.model.Idea
import com.chrisallenclark.remli.model.ImportanceLevel
import java.util.Locale

/**
 * The importance score, shown and made arguable. Port of ImportanceControl.swift.
 *
 * The guess stays on screen after you disagree, and changing it changes what Remli does —
 * resurfacing and node size both read `Idea.importance`.
 */
@Composable
fun ImportanceControl(idea: Idea, onSet: (ImportanceLevel?) -> Unit) {
    val p = palette
    val current = idea.importanceLevel
    val selectedIndex = current.ordinal
    val ring by animateColorAsState(
        if (idea.importanceIsUserSet) p.ember.copy(alpha = 0.45f) else Color.Transparent,
        Theme.Motion.standard(), label = "ring",
    )
    Column(
        Modifier
            .fillMaxWidth()
            .border(1.dp, ring, ContinuousShape(Theme.Radius.md))
            .cardBackground()
            .testTag("importance"),
        verticalArrangement = Arrangement.spacedBy(Theme.Space.sm),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Txt("IMPORTANCE", Theme.Typography.monoCaption.copy(letterSpacing = 1.1.sp), p.inkMuted, Modifier.weight(1f))
            Txt(format(idea.importance), Theme.Typography.monoCaption, p.ember)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(Theme.Space.xxs)) {
            ImportanceLevel.entries.forEach { level ->
                val index = level.ordinal
                val fill by animateColorAsState(
                    when {
                        index == selectedIndex -> p.ember
                        index < selectedIndex -> p.ember.copy(alpha = 0.34f)
                        else -> p.hairline
                    },
                    Theme.Motion.standard(), label = "fill",
                )
                Column(
                    Modifier
                        .weight(1f)
                        .semantics { selected = index == selectedIndex }
                        .pressable(label = "${level.label}. ${level.effect}", role = Role.Button) {
                            // Tapping the level you are already on clears back to the guess.
                            onSet(if (level == current && idea.importanceIsUserSet) null else level)
                        },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Spacer(Modifier.fillMaxWidth().height(5.dp).background(fill, CircleShape))
                    Txt(
                        level.label,
                        Theme.Typography.caption2.copy(
                            fontSize = 10.sp,
                            fontWeight = if (index == selectedIndex) FontWeight.SemiBold else FontWeight.Normal,
                        ),
                        if (index == selectedIndex) p.ink else p.inkMuted,
                        maxLines = 2,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }

        Provenance(idea, onUseGuess = { onSet(null) })

        Hairline()

        Txt(current.effect, Theme.Typography.meta, p.inkMuted.copy(alpha = 0.8f))
    }
}

@Composable
private fun Provenance(idea: Idea, onUseGuess: () -> Unit) {
    val p = palette
    when {
        idea.importanceIsUserSet -> Row(verticalAlignment = Alignment.Top) {
            Txt(
                "You set this. Remli guessed ${idea.importanceGuessLevel.label.lowercase()} — ${format(idea.importanceScore)}.",
                Theme.Typography.meta, p.inkMuted, Modifier.weight(1f),
            )
            Txt("Use the guess", Theme.Typography.meta, p.ember, Modifier.padding(start = Theme.Space.xs).pressable(onClick = onUseGuess))
        }
        idea.isEnriched -> Txt("Remli's guess. Tap a level to change it.", Theme.Typography.meta, p.inkMuted)
        else -> Txt("Not judged yet — set it yourself, or wait for Remli to read it.", Theme.Typography.meta, p.inkMuted)
    }
}

/** `String(format: "%.2f")`, always with a full stop, as iOS's POSIX format does. */
private fun format(value: Double) = String.format(Locale.ROOT, "%.2f", value)

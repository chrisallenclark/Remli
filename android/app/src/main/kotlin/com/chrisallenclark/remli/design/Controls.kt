package com.chrisallenclark.remli.design

import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties

/** UIKit's destructive red, light and dark. */
val DestructiveRed: Color @Composable get() = if (palette.isDark) Color(0xFFFF453A) else Color(0xFFFF3B30)

data class MenuItem(
    val label: String,
    val symbol: Symbol,
    val destructive: Boolean = false,
    /** Draws a separator above this item, as SwiftUI's `Divider()` inside a `Menu` does. */
    val dividerBefore: Boolean = false,
    val action: () -> Unit,
)

/**
 * A pull-down menu as iOS draws one: a rounded, frosted panel of full-width rows, label on
 * the left and glyph on the right, destructive rows in red. Used for both the "⋯" menu and
 * long-press context menus.
 */
@Composable
fun IosMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    items: List<MenuItem>,
) {
    val state = remember { MutableTransitionState(false) }
    state.targetState = expanded
    if (!state.currentState && !state.targetState && state.isIdle) return

    val gap = with(androidx.compose.ui.platform.LocalDensity.current) { 6.dp.roundToPx() }
    Popup(
        popupPositionProvider = remember(gap) { BelowAnchorEnd(gap) },
        onDismissRequest = onDismiss,
        properties = PopupProperties(focusable = true),
    ) {
        AnimatedVisibility(
            visibleState = state,
            enter = scaleIn(Theme.Motion.standard(), initialScale = 0.6f, transformOrigin = TransformOrigin(1f, 0f)) + fadeIn(Theme.Motion.standard()),
            exit = scaleOut(Theme.Motion.standard(), targetScale = 0.8f, transformOrigin = TransformOrigin(1f, 0f)) + fadeOut(Theme.Motion.standard()),
        ) {
            val shape = ContinuousShape(Theme.Radius.lg)
            Column(
                Modifier
                    .testTag("menu")
                    .padding(Theme.Space.xs)
                    .width(250.dp)
                    .shadow(24.dp, shape, ambientColor = Color.Black.copy(alpha = 0.25f), spotColor = Color.Black.copy(alpha = 0.25f))
                    .background(palette.surface.copy(alpha = 0.97f), shape)
                    .border(0.5.dp, palette.hairline, shape)
                    .padding(vertical = 6.dp),
            ) {
                items.forEachIndexed { index, item ->
                    if (item.dividerBefore && index > 0) {
                        Spacer(Modifier.fillMaxWidth().padding(vertical = 4.dp).height(6.dp).background(palette.hairline.copy(alpha = 0.6f)))
                    }
                    val color = if (item.destructive) DestructiveRed else palette.ink
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .pressable(label = item.label) { onDismiss(); item.action() }
                            .padding(horizontal = Theme.Space.md, vertical = 11.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Txt(item.label, Theme.Typography.body, color, Modifier.weight(1f))
                        SymbolIcon(item.symbol, color, 17.dp)
                    }
                }
            }
        }
    }
}

/**
 * Opens below the control that summoned it, right edges aligned, as an iOS pull-down menu
 * does — and above it instead when there is no room below.
 */
private class BelowAnchorEnd(private val gap: Int) : PopupPositionProvider {
    override fun calculatePosition(
        anchorBounds: IntRect,
        windowSize: IntSize,
        layoutDirection: LayoutDirection,
        popupContentSize: IntSize,
    ): IntOffset {
        val x = (anchorBounds.right - popupContentSize.width).coerceIn(0, (windowSize.width - popupContentSize.width).coerceAtLeast(0))
        val below = anchorBounds.bottom + gap
        val y = if (below + popupContentSize.height <= windowSize.height) below
        else (anchorBounds.top - gap - popupContentSize.height).coerceAtLeast(0)
        return IntOffset(x, y)
    }
}

/**
 * `Picker(...).pickerStyle(.segmented)`: a recessed track with a raised thumb that slides to
 * the selection on the standard spring.
 */
@Composable
fun <T> SegmentedControl(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val p = palette
    val track = if (p.isDark) Color(0x3D767680) else Color(0x1F767680)
    val thumb = if (p.isDark) Color(0xFF636366) else Color.White
    val shape = CircleShape
    BoxWithConstraints(
        modifier
            .fillMaxWidth()
            .height(34.dp)
            .background(track, shape)
            .padding(2.dp),
    ) {
        val segment = maxWidth / options.size
        val index = options.indexOf(selected).coerceAtLeast(0)
        val x by animateDpAsState(segment * index, Theme.Motion.standard(), label = "thumb")
        Box(
            Modifier
                .offset(x = x)
                .width(segment)
                .fillMaxHeight()
                .shadow(3.dp, shape, ambientColor = Color.Black.copy(alpha = 0.12f), spotColor = Color.Black.copy(alpha = 0.12f))
                .background(thumb, shape),
        )
        Row(Modifier.fillMaxWidth().fillMaxHeight()) {
            options.forEach { option ->
                val isSelected = option == selected
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .semantics { this.selected = isSelected }
                        .pressable(label = label(option), role = Role.Tab) { onSelect(option) },
                    contentAlignment = Alignment.Center,
                ) {
                    Txt(
                        label(option),
                        if (isSelected) SegmentSelected
                        else SegmentNormal,
                        p.ink,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

/** A capsule chip: icon and label. Selected chips are filled with ember, as on the Ideas list. */
@Composable
fun Chip(
    label: String,
    symbol: Symbol,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val p = palette
    val fg = if (selected) p.canvas else p.inkMuted
    Row(
        modifier
            .background(if (selected) p.ember else p.surface, CircleShape)
            .then(if (selected) Modifier else Modifier.border(0.5.dp, p.hairline, CircleShape))
            .pressable(label = label, role = Role.Tab, onClick = onClick)
            .padding(horizontal = Theme.Space.sm, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SymbolIcon(symbol, fg, 10.dp)
        Txt(label, Theme.Typography.meta, fg, maxLines = 1)
    }
}

private val SegmentNormal = Theme.Typography.sectionLabel
private val SegmentSelected = Theme.Typography.sectionLabel.copy(fontWeight = FontWeight.SemiBold)

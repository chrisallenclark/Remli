package com.chrisallenclark.remli.design

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The system chrome iOS draws for free — bars, bar buttons, the frosted material behind
 * them — rebuilt to look like iOS rather than like Material.
 *
 * **Frosted glass is approximated in A1.** iOS blurs whatever scrolls behind its bars. That
 * needs a backdrop blur, which Android only has from 12 and which A1 does not attempt yet;
 * bars here use a translucent surface of the same tint, which is also exactly the fallback
 * DeviceCapabilities promises older and low-memory phones. Tracked in PARITY.md.
 */
object Chrome {
    /** iOS's minimum hit target, and the diameter of an iOS 26 glass bar button. */
    val barButton = 44.dp

    /** The inline navigation bar's height, below the status bar. */
    val barHeight = 52.dp

    @Composable
    fun materialFill(): Color = palette.surface.copy(alpha = if (palette.isDark) 0.78f else 0.82f)
}

/** Fades and shrinks slightly while held, as UIKit controls do. Never a Material ripple. */
@Composable
fun Modifier.pressable(
    enabled: Boolean = true,
    label: String? = null,
    role: Role = Role.Button,
    onClick: () -> Unit,
): Modifier {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val alpha by animateFloatAsState(if (pressed) 0.55f else 1f, Theme.Motion.standard(), label = "press")
    return this
        .then(if (label != null) Modifier.semantics { contentDescription = label } else Modifier)
        .alpha(if (enabled) alpha else 0.35f)
        .clickable(interactionSource = interaction, indication = null, enabled = enabled, role = role, onClick = onClick)
}

/** An iOS 26 bar button: a glyph in a frosted circle. */
@Composable
fun GlassIconButton(symbol: Symbol, label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(Chrome.barButton)
            .glass(CircleShape)
            .pressable(label = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        SymbolIcon(symbol, palette.ink, 17.dp)
    }
}

/** A text bar button in a frosted capsule — Cancel, Save, Done. */
@Composable
fun GlassTextButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    bold: Boolean = false,
    enabled: Boolean = true,
    prominent: Boolean = false,
) {
    val p = palette
    val fill = if (prominent && enabled) p.ember else null
    Box(
        modifier = modifier
            .height(Chrome.barButton)
            .widthIn(min = Chrome.barButton)
            .then(if (fill != null) Modifier.background(fill, CircleShape) else Modifier.glass(CircleShape))
            .pressable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        BasicText(
            text,
            style = (if (bold) Theme.Typography.barButtonBold else Theme.Typography.barButton)
                .copy(color = if (fill != null) p.canvas else p.ink),
        )
    }
}

/** The frosted material behind bars, as a modifier. See [Chrome] for what A1 approximates. */
@Composable
fun Modifier.glass(shape: Shape): Modifier {
    val p = palette
    return this
        .background(Chrome.materialFill(), shape)
        .border(0.5.dp, p.hairline.copy(alpha = 0.9f), shape)
}

/**
 * An inline navigation bar: leading control, centred title, trailing controls. Used by
 * sheets and pushed screens, where iOS sets `.navigationBarTitleDisplayMode(.inline)`.
 */
@Composable
fun InlineNavBar(
    title: String,
    modifier: Modifier = Modifier,
    titleAlpha: Float = 1f,
    background: Color = Color.Transparent,
    insetForStatusBar: Boolean = true,
    leading: @Composable RowScope.() -> Unit = {},
    trailing: @Composable RowScope.() -> Unit = {},
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(background)
            .then(if (insetForStatusBar) Modifier.windowInsetsPadding(WindowInsets.statusBars) else Modifier)
            .height(Chrome.barHeight)
            .padding(horizontal = Theme.Space.md),
    ) {
        Row(Modifier.align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically, content = leading)
        BasicText(
            title,
            modifier = Modifier.align(Alignment.Center).alpha(titleAlpha).padding(horizontal = 96.dp),
            style = Theme.Typography.inlineNavTitle.copy(color = palette.ink),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Row(
            Modifier.align(Alignment.CenterEnd),
            horizontalArrangement = Arrangement.spacedBy(Theme.Space.xs),
            verticalAlignment = Alignment.CenterVertically,
            content = trailing,
        )
    }
}

/** iOS's large navigation title, which scrolls away with the content beneath the inline bar. */
@Composable
fun LargeTitle(text: String, modifier: Modifier = Modifier) {
    BasicText(
        text,
        modifier = modifier.padding(start = Theme.Space.md, end = Theme.Space.md, top = 2.dp, bottom = Theme.Space.xs),
        style = Theme.Typography.largeNavTitle.copy(color = palette.ink),
    )
}

/** Uppercase, tracked section label — `Text("STATUS").font(.sectionLabel).tracking(0.6)`. */
@Composable
fun SectionLabel(text: String, modifier: Modifier = Modifier, style: TextStyle = Theme.Typography.sectionLabel) {
    BasicText(
        text.uppercase(),
        modifier = modifier,
        style = style.copy(color = palette.inkMuted, letterSpacing = 0.6.sp),
    )
}

/** The hairline divider iOS lists and forms use. */
@Composable
fun Hairline(modifier: Modifier = Modifier, color: Color = palette.hairline) {
    Spacer(modifier.fillMaxWidth().height(0.5.dp).background(color))
}

/** `Text(…)` with a colour, the most common thing in every view. */
@Composable
fun Txt(
    text: String,
    style: TextStyle,
    color: Color,
    modifier: Modifier = Modifier,
    maxLines: Int = Int.MAX_VALUE,
    textAlign: androidx.compose.ui.text.style.TextAlign? = null,
) {
    BasicText(
        text,
        modifier = modifier,
        style = if (textAlign != null) style.copy(color = color, textAlign = textAlign) else style.copy(color = color),
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
    )
}

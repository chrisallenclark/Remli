package com.chrisallenclark.remli.design

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.R

/**
 * The icons Remli draws, keyed by the SF Symbol each one stands in for.
 *
 * SF Symbols may only be used on Apple platforms, so Android draws Material Symbols
 * (Rounded, the closest in stroke and terminals). The iOS name is kept for two reasons: the
 * library stores SF names (a Space's icon is saved as one), and it makes this file the one
 * place to look when an iOS screen gains an icon.
 *
 * A name with no entry renders [fallback] rather than nothing — a blank icon looks like a
 * bug, which is the same reason iOS validates every symbol name before use.
 */
enum class Symbol(val sfName: String, @param:DrawableRes val drawable: Int) {
    // Tabs and toolbars
    SquareStack("square.stack", R.drawable.ms_stacks),
    SquareStackFill("square.stack.fill", R.drawable.ms_stacks_fill1),
    SquareGrid2x2("square.grid.2x2", R.drawable.ms_grid_view),
    SquareGrid2x2Fill("square.grid.2x2.fill", R.drawable.ms_grid_view_fill1),
    MapGraph("point.3.filled.connected.trianglepath.dotted", R.drawable.ms_hub),
    MapGraphFill("point.3.filled.connected.trianglepath.dotted.fill", R.drawable.ms_hub_fill1),
    Branch("arrow.triangle.branch", R.drawable.ms_alt_route),
    BranchFill("arrow.triangle.branch.fill", R.drawable.ms_alt_route_fill1),
    Review("calendar.day.timeline.left", R.drawable.ms_calendar_view_day),
    Gear("gearshape", R.drawable.ms_settings),
    PlusCircleFill("plus.circle.fill", R.drawable.ms_add_circle_fill1),
    EllipsisCircle("ellipsis.circle", R.drawable.ms_pending),
    Ellipsis("ellipsis", R.drawable.ms_more_horiz),
    ChevronRight("chevron.right", R.drawable.ms_chevron_right),
    ChevronLeft("chevron.left", R.drawable.ms_arrow_back_ios_new),
    Close("xmark", R.drawable.ms_close),
    Checkmark("checkmark", R.drawable.ms_check),

    // Idea actions
    Pin("pin", R.drawable.ms_push_pin),
    PinFill("pin.fill", R.drawable.ms_push_pin_fill1),
    PinSlash("pin.slash", R.drawable.ms_keep_off),
    Trash("trash", R.drawable.ms_delete),
    Pencil("pencil", R.drawable.ms_edit),
    Flag("flag", R.drawable.ms_flag),
    // Material has no struck-through flag; the menu label carries the meaning.
    FlagSlash("flag.slash", R.drawable.ms_flag),
    SquareStack3dUp("square.stack.3d.up", R.drawable.ms_layers),

    // States and collections
    LightbulbMax("lightbulb.max", R.drawable.ms_emoji_objects),
    Lightbulb("lightbulb", R.drawable.ms_lightbulb),
    CheckmarkCircle("checkmark.circle", R.drawable.ms_check_circle),
    Bolt("bolt", R.drawable.ms_bolt),
    CircleLeftHalfFilled("circle.lefthalf.filled", R.drawable.ms_contrast),
    ArrowTurnDownRight("arrow.turn.down.right", R.drawable.ms_subdirectory_arrow_right),

    // Appearance
    Iphone("iphone", R.drawable.ms_smartphone),
    SunMax("sun.max", R.drawable.ms_light_mode),
    Moon("moon", R.drawable.ms_dark_mode);

    companion object {
        val fallback = Lightbulb
        private val bySfName = entries.associateBy { it.sfName }

        /** The drawable for a stored SF Symbol name. Never blank. */
        fun forSfName(name: String?): Symbol = name?.let { bySfName[it] } ?: fallback
    }
}

/**
 * An icon at a given point size. SF Symbols are sized by font size and Material glyphs by
 * their box; a Material glyph fills about 20/24 of its box, so it is drawn slightly larger
 * than the SF point size to match the optical size of the iOS glyph.
 */
@Composable
fun SymbolIcon(symbol: Symbol, tint: Color, size: Dp, modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(symbol.drawable),
        contentDescription = null,
        colorFilter = ColorFilter.tint(tint),
        modifier = modifier.size(size * OPTICAL_SCALE),
    )
}

private const val OPTICAL_SCALE = 1.2f

val Dp.Companion.Hairline: Dp get() = 0.5.dp

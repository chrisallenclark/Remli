package com.chrisallenclark.remli.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/**
 * Remli's colours, copied value for value from the iOS asset catalog
 * (`Resources/Assets.xcassets/<Name>.colorset`) and `Theme.Palette` in
 * `Sources/Shared/Design/Theme.swift`.
 *
 * If a value here ever differs from the iOS file of the same name, iOS is right and this
 * is the bug. A1 grows this into the full design system; the colours are here from A0 so
 * the very first build already looks like Remli rather than like a template.
 */
@Immutable
data class RemliPalette(
    val canvas: Color,
    val surface: Color,
    val ink: Color,
    val inkMuted: Color,
    val hairline: Color,
    val ember: Color,
) {
    companion object {
        val Light = RemliPalette(
            canvas = Color(0xFFF6F4F0),
            surface = Color(0xFFFFFFFF),
            ink = Color(0xFF16161A),
            inkMuted = Color(0xFF63605A),
            hairline = Color(0xFFE4E1DB),
            ember = Color(0xFF2E2A24),
        )

        val Dark = RemliPalette(
            canvas = Color(0xFF09080B),
            surface = Color(0xFF17151A),
            ink = Color(0xFFF2F0EC),
            inkMuted = Color(0xFF9C948E),
            hairline = Color(0xFF2B2731),
            ember = Color(0xFFE2C49E),
        )
    }
}

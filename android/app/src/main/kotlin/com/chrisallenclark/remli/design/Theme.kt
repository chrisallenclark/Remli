package com.chrisallenclark.remli.design

import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.chrisallenclark.remli.R
import kotlin.math.PI
import kotlin.math.pow

/**
 * Remli's design system. Port of Sources/Shared/Design/Theme.swift.
 *
 * Everything visual comes from here. The values are the iOS values: if a number in this
 * file differs from the same name in Theme.swift or the asset catalog, iOS is right.
 * Points become dp and text sizes become sp one-for-one, which is how both platforms
 * define their density-independent unit.
 */
object Theme {

    /** Colours, from Resources/Assets.xcassets/<Name>.colorset, light and dark. */
    @Immutable
    data class Palette(
        val canvas: Color,
        val surface: Color,
        val ink: Color,
        val inkMuted: Color,
        val hairline: Color,
        val ember: Color,
        val isDark: Boolean,
    ) {
        companion object {
            val Light = Palette(
                canvas = Color(0xFFF6F4F0),
                surface = Color(0xFFFFFFFF),
                ink = Color(0xFF16161A),
                inkMuted = Color(0xFF63605A),
                hairline = Color(0xFFE4E1DB),
                ember = Color(0xFF2E2A24),
                isDark = false,
            )
            val Dark = Palette(
                canvas = Color(0xFF09080B),
                surface = Color(0xFF17151A),
                ink = Color(0xFFF2F0EC),
                inkMuted = Color(0xFF9C948E),
                hairline = Color(0xFF2B2731),
                ember = Color(0xFFE2C49E),
                isDark = true,
            )
        }

        /** The Map's ground, which stays dark in both appearances (Theme.Palette.night / dusk). */
        val mapGround: Color get() = if (isDark) Night else Dusk
    }

    val Night = Color(red = 0.035f, green = 0.031f, blue = 0.043f)
    val Dusk = Color(red = 0.145f, green = 0.141f, blue = 0.133f)

    /** A 4pt scale. */
    object Space {
        val xxs = 4.dp
        val xs = 8.dp
        val sm = 12.dp
        val md = 16.dp
        val lg = 24.dp
        val xl = 32.dp
        val xxl = 48.dp
    }

    object Radius {
        val sm = 8.dp
        val md = 14.dp
        val lg = 22.dp
    }

    /**
     * Type. Idea text is set in a serif because it reads as writing rather than interface;
     * everything structural is in a sans.
     *
     * iOS uses New York and SF Pro, neither of which may be shipped on Android. The stand-ins
     * are Source Serif 4 — which, like New York, has optical sizes, so the display cut is
     * used for large titles and the text cut for reading — and Inter. Sizes and line heights
     * are the iOS text styles at the default Dynamic Type size; sp makes them follow the
     * phone's font-size setting the way Dynamic Type does.
     */
    object Typography {
        val SerifText = FontFamily(Font(R.font.serif_text, FontWeight.Normal))
        val SerifDisplay = FontFamily(Font(R.font.serif_display, FontWeight.Normal))
        val Sans = FontFamily(
            Font(R.font.inter_regular, FontWeight.Normal),
            Font(R.font.inter_medium, FontWeight.Medium),
            Font(R.font.inter_semibold, FontWeight.SemiBold),
        )
        val SansDisplay = FontFamily(Font(R.font.inter_display_bold, FontWeight.Bold))

        // Theme.Typography, one for one.
        val display = TextStyle(fontFamily = SerifDisplay, fontSize = 34.sp, lineHeight = 41.sp)
        val title = TextStyle(fontFamily = SerifDisplay, fontSize = 22.sp, lineHeight = 28.sp)
        val ideaBody = TextStyle(fontFamily = SerifText, fontSize = 17.sp, lineHeight = 22.sp)
        val sectionLabel = TextStyle(fontFamily = Sans, fontWeight = FontWeight.Medium, fontSize = 13.sp, lineHeight = 18.sp)
        val meta = TextStyle(fontFamily = Sans, fontSize = 12.sp, lineHeight = 16.sp)
        val control = TextStyle(fontFamily = Sans, fontWeight = FontWeight.Medium, fontSize = 15.sp, lineHeight = 20.sp)

        // System chrome iOS draws without Theme: navigation titles, bar buttons, tab labels.
        val largeNavTitle = TextStyle(fontFamily = SansDisplay, fontWeight = FontWeight.Bold, fontSize = 34.sp, lineHeight = 41.sp, letterSpacing = 0.01.em)
        val inlineNavTitle = TextStyle(fontFamily = Sans, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 22.sp)
        val barButton = TextStyle(fontFamily = Sans, fontSize = 17.sp, lineHeight = 22.sp)
        val barButtonBold = barButton.copy(fontWeight = FontWeight.SemiBold)
        val body = TextStyle(fontFamily = Sans, fontSize = 17.sp, lineHeight = 22.sp)
        val tabLabel = TextStyle(fontFamily = Sans, fontWeight = FontWeight.Medium, fontSize = 10.sp, lineHeight = 12.sp)
        val caption2 = TextStyle(fontFamily = Sans, fontSize = 11.sp, lineHeight = 13.sp)
        val monoCaption = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 11.sp, lineHeight = 13.sp)
    }

    /**
     * SwiftUI springs, converted. SwiftUI describes a spring by response (its period) and
     * damping fraction; Compose by stiffness and damping ratio. For unit mass,
     * stiffness = (2π / response)², and the damping fraction is the damping ratio — so these
     * are the same physical springs, not look-alikes.
     */
    object Motion {
        private fun swiftUISpring(response: Double, dampingFraction: Float): Float =
            (2 * PI / response).pow(2).toFloat().also { check(dampingFraction > 0) }

        /** spring(response: 0.34, dampingFraction: 0.82) */
        val standardStiffness = swiftUISpring(0.34, 0.82f)
        const val standardDamping = 0.82f

        /** spring(response: 0.46, dampingFraction: 0.78) */
        val expressiveStiffness = swiftUISpring(0.46, 0.78f)
        const val expressiveDamping = 0.78f

        fun <T> standard(): FiniteAnimationSpec<T> = spring(dampingRatio = standardDamping, stiffness = standardStiffness)
        fun <T> expressive(): FiniteAnimationSpec<T> = spring(dampingRatio = expressiveDamping, stiffness = expressiveStiffness)
    }
}

val LocalPalette = staticCompositionLocalOf { Theme.Palette.Light }

/** The current palette. Read inside composables: `palette.ink`. */
val palette: Theme.Palette
    @Composable get() = LocalPalette.current

@Composable
fun RemliTheme(dark: Boolean, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalPalette provides if (dark) Theme.Palette.Dark else Theme.Palette.Light, content = content)
}

/** A raised card. Port of `CardBackground`: surface fill, half-point hairline, 14pt corners. */
@Composable
fun Modifier.cardBackground(padding: Dp = Theme.Space.md): Modifier {
    val p = palette
    val shape = ContinuousShape(Theme.Radius.md)
    return this
        .background(p.surface, shape)
        .border(0.5.dp, p.hairline, shape)
        .padding(padding)
}

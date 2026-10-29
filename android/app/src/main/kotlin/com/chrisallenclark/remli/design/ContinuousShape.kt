package com.chrisallenclark.remli.design

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import kotlin.math.min

/**
 * iOS's `RoundedRectangle(cornerRadius:style: .continuous)`.
 *
 * A circular-arc corner — what Android's RoundedCornerShape draws — has a visible kink where
 * the straight edge meets the curve. Apple's continuous corner eases into the curve over a
 * longer run, which is most of why an iOS card looks the way it does. These control points
 * are the widely used reconstruction of UIBezierPath's continuous rounded rect: the curve
 * begins 1.528 × radius from the corner and is drawn as three cubics.
 *
 * When the shape is too small for that run (a capsule, say) iOS falls back to a plain
 * rounded rect, and so does this.
 */
class ContinuousShape(private val radius: Dp) : Shape {

    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline {
        val r = with(density) { radius.toPx() }
        val limit = min(size.width, size.height) / 2f / RUN
        if (r > limit) {
            return RoundedCornerShape(radius).createOutline(size, layoutDirection, density)
        }
        return Outline.Generic(path(size.width, size.height, r))
    }

    private fun path(w: Float, h: Float, r: Float) = Path().apply {
        moveTo(RUN * r, 0f)
        // Top edge, top-right corner.
        lineTo(w - RUN * r, 0f)
        cubicTo(w - A * r, 0f, w - B * r, 0f, w - C * r, D * r)
        cubicTo(w - E * r, F * r, w - F * r, E * r, w - D * r, C * r)
        cubicTo(w, B * r, w, A * r, w, RUN * r)
        // Right edge, bottom-right corner.
        lineTo(w, h - RUN * r)
        cubicTo(w, h - A * r, w, h - B * r, w - D * r, h - C * r)
        cubicTo(w - F * r, h - E * r, w - E * r, h - F * r, w - C * r, h - D * r)
        cubicTo(w - B * r, h, w - A * r, h, w - RUN * r, h)
        // Bottom edge, bottom-left corner.
        lineTo(RUN * r, h)
        cubicTo(A * r, h, B * r, h, C * r, h - D * r)
        cubicTo(E * r, h - F * r, F * r, h - E * r, D * r, h - C * r)
        cubicTo(0f, h - B * r, 0f, h - A * r, 0f, h - RUN * r)
        // Left edge, top-left corner.
        lineTo(0f, RUN * r)
        cubicTo(0f, A * r, 0f, B * r, D * r, C * r)
        cubicTo(F * r, E * r, E * r, F * r, C * r, D * r)
        cubicTo(B * r, 0f, A * r, 0f, RUN * r, 0f)
        close()
    }

    override fun equals(other: Any?) = other is ContinuousShape && other.radius == radius
    override fun hashCode() = radius.hashCode()

    private companion object {
        const val RUN = 1.52866483f
        const val A = 1.08849323f
        const val B = 0.86840689f
        const val C = 0.63149399f
        const val D = 0.07491100f
        const val E = 0.37282392f
        const val F = 0.19824899f
    }
}

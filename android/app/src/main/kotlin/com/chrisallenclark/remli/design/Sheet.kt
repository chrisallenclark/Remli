package com.chrisallenclark.remli.design

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth

import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * How far any sheet is presented, 0–1. The root reads it to recede the app behind the sheet
 * the way iOS does, so the sheet reads as a card laid on top rather than a new screen.
 */
@Stable
class SheetPresentation {
    var progress by mutableFloatStateOf(0f)
        internal set
}

/**
 * An iOS page sheet: slides up on a spring, sits a little below the status bar with large
 * rounded top corners and a grabber, and can be dragged down or backed out of.
 *
 * [dismissEnabled] mirrors `.interactiveDismissDisabled` — when false, neither dragging nor
 * the back gesture closes it.
 */
@Composable
fun Sheet(
    visible: Boolean,
    onDismiss: () -> Unit,
    presentation: SheetPresentation,
    modifier: Modifier = Modifier,
    dismissEnabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    val progress = remember { Animatable(0f) }
    var composed by remember { mutableStateOf(visible) }
    val drag = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(visible) {
        if (visible) {
            composed = true
            drag.snapTo(0f)
            progress.animateTo(1f, Theme.Motion.expressive())
        } else {
            progress.animateTo(0f, Theme.Motion.standard())
            composed = false
            presentation.progress = 0f
        }
    }

    if (!composed) return
    // Published after composition, not during it: the root reads this to recede the app.
    SideEffect { presentation.progress = progress.value }

    BackHandler(enabled = visible && dismissEnabled, onBack = onDismiss)

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val heightPx = with(LocalDensity.current) { maxHeight.toPx() }
        val dismissDistance = with(LocalDensity.current) { 140.dp.toPx() }

        // The dimming behind the sheet. Tapping it does what dragging down does.
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.28f * progress.value))
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    enabled = visible && dismissEnabled,
                    onClick = onDismiss,
                ),
        )

        val shape = RoundedCornerShape(topStart = SheetRadius, topEnd = SheetRadius)
        Column(
            modifier = modifier
                .testTag("sheet")
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.statusBars)
                .padding(top = 10.dp)
                .offset { IntOffset(0, ((1f - progress.value) * heightPx + drag.value).roundToInt()) }
                .clip(shape)
                .background(palette.canvas, shape)
                .draggable(
                    orientation = Orientation.Vertical,
                    enabled = dismissEnabled,
                    state = rememberDraggableState { delta ->
                        scope.launch { drag.snapTo((drag.value + delta).coerceAtLeast(0f)) }
                    },
                    onDragStopped = { velocity ->
                        if (drag.value > dismissDistance || velocity > 2400f) onDismiss()
                        else scope.launch { drag.animateTo(0f, Theme.Motion.standard()) }
                    },
                ),
        ) {
            Box(Modifier.fillMaxWidth().padding(top = 5.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.size(width = 36.dp, height = 5.dp).background(palette.inkMuted.copy(alpha = 0.35f), CircleShape))
            }
            content()
        }
    }
}

/** iOS 26 sheets have generously rounded tops. */
private val SheetRadius = 28.dp


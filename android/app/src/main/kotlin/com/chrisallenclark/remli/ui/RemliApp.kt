package com.chrisallenclark.remli.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.capabilities.DeviceCapabilities
import com.chrisallenclark.remli.data.IdeaStore
import com.chrisallenclark.remli.design.AppearanceStore
import com.chrisallenclark.remli.design.Chrome
import com.chrisallenclark.remli.design.ContinuousShape
import com.chrisallenclark.remli.design.GlassIconButton
import com.chrisallenclark.remli.design.InlineNavBar
import com.chrisallenclark.remli.design.RemliTheme
import com.chrisallenclark.remli.design.Sheet
import com.chrisallenclark.remli.design.SheetPresentation
import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.design.SymbolIcon
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.palette
import com.chrisallenclark.remli.design.pressable
import kotlinx.coroutines.delay

/**
 * The app shell. Port of RootView.swift: four tabs, Capture as a floating action rather
 * than a tab, Settings as a sheet.
 *
 * Review's toolbar button is not here yet — it arrives with Review in A6, and a button that
 * opens nothing would be a dead control.
 */
@Composable
fun RemliApp(
    store: IdeaStore,
    appearanceStore: AppearanceStore,
    capabilities: DeviceCapabilities,
    onDarkChanged: (Boolean) -> Unit = {},
) {
    val dark = appearanceStore.appearance.isDark ?: isSystemInDarkTheme()
    LaunchedEffect(dark) { onDarkChanged(dark) }

    RemliTheme(dark) {
        val library by store.library.collectAsState()
        val isLoaded by store.isLoaded.collectAsState()
        val presentation = remember { SheetPresentation() }
        var tab by rememberSaveable { mutableStateOf(Tab.Ideas) }
        var openIdeaId by rememberSaveable { mutableStateOf<String?>(null) }
        var capturing by rememberSaveable { mutableStateOf(false) }
        var showingSettings by rememberSaveable { mutableStateOf(false) }

        // Relative dates ("3 minutes ago") have to move on by themselves.
        var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
        LaunchedEffect(Unit) { while (true) { delay(30_000); now = System.currentTimeMillis() } }

        // An idea deleted elsewhere (or from its own menu) closes its screen.
        val openIdea = openIdeaId?.let { library.idea(it) }
        LaunchedEffect(openIdeaId, library) {
            if (openIdeaId != null && library.idea(openIdeaId!!) == null && store.isLoaded.value) openIdeaId = null
        }

        BackHandler(enabled = tab == Tab.Ideas && openIdeaId != null) { openIdeaId = null }

        val p = palette
        val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
        val tabBarSpace = TabBarHeight + navBottom + Theme.Space.xs
        val captureSpace = 64.dp
        val topInset = topBarInset()
        val listState = rememberLazyListState()
        val pastTitle by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 60 } }

        Box(Modifier.fillMaxSize().background(Color.Black)) {
            // The app recedes behind a sheet, as iOS does with a page sheet.
            val progress = presentation.progress
            Box(
                Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        val s = 1f - 0.06f * progress
                        scaleX = s; scaleY = s
                        alpha = 1f - 0.15f * progress
                    }
                    .clip(if (progress > 0f) ContinuousShape(28.dp) else RectangleShape)
                    .background(p.canvas),
            ) {
                when (tab) {
                    Tab.Ideas -> {

                        AnimatedContent(
                            targetState = openIdea?.id,
                            transitionSpec = { pushPop(forward = targetState != null) },
                            label = "ideas-nav",
                        ) { id ->
                            val idea = id?.let { library.idea(it) }
                            if (idea == null) {
                                Box(Modifier.fillMaxSize().background(p.canvas)) {
                                    IdeasListScreen(
                                        library = library,
                                        isLoaded = isLoaded,
                                        now = now,
                                        topInset = topInset,
                                        bottomInset = tabBarSpace + captureSpace,
                                        onOpen = { openIdeaId = it.id },
                                        onTogglePin = { store.togglePin(it.id) },
                                        onDelete = { store.delete(it.id) },
                                        state = listState,
                                    )
                                    InlineNavBar(
                                        title = "Ideas",
                                        titleAlpha = if (pastTitle) 1f else 0f,
                                        background = if (pastTitle) Chrome.materialFill() else Color.Transparent,
                                        trailing = {
                                            GlassIconButton(Symbol.Gear, "Settings", onClick = { showingSettings = true }, modifier = Modifier.testTag("open-settings"))
                                        },
                                    )
                                    CaptureButton(
                                        onClick = { capturing = true },
                                        modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = tabBarSpace),
                                    )
                                }
                            } else {
                                IdeaDetailScreen(
                                    idea = idea,
                                    actions = IdeaActions(
                                        setTitle = { store.setTitle(idea.id, it) },
                                        setText = { store.setText(idea.id, it) },
                                        togglePin = { store.togglePin(idea.id) },
                                        toggleGoal = { store.toggleGoal(idea.id) },
                                        setStatus = { store.setStatus(idea.id, it) },
                                        setImportance = { store.setImportance(idea.id, it) },
                                        delete = { openIdeaId = null; store.delete(idea.id) },
                                    ),
                                    onBack = { openIdeaId = null },
                                    bottomInset = tabBarSpace,
                                )
                            }
                        }
                    }
                    Tab.Spaces -> PlaceholderTab("Spaces", Symbol.SquareGrid2x2, "Your Spaces, as a deck you swipe through, arrive in a later Android build.", topInset, tabBarSpace)
                    Tab.Map -> PlaceholderTab("Map", Symbol.MapGraph, "The map of how your ideas connect arrives once Remli can find connections on Android.", topInset, tabBarSpace)
                    Tab.Roadmaps -> PlaceholderTab("Roadmaps", Symbol.Branch, "Routes from where you are to a finished idea arrive with connections.", topInset, tabBarSpace)
                }

                TabBar(
                    selected = tab,
                    onSelect = { tab = it },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = navBottom + Theme.Space.xs)
                        .padding(horizontal = 20.dp),
                )
            }

            Sheet(visible = capturing, onDismiss = { capturing = false }, presentation = presentation) {
                CaptureSheet(
                    onCancel = { capturing = false },
                    onSave = { text, name ->
                        // Write first, think later: the idea is on disk before the sheet closes.
                        store.capture(text, name)
                        capturing = false
                    },
                )
            }
            Sheet(visible = showingSettings, onDismiss = { showingSettings = false }, presentation = presentation) {
                SettingsSheet(
                    appearance = appearanceStore.appearance,
                    onAppearance = appearanceStore::set,
                    capabilities = capabilities,
                    onDone = { showingSettings = false },
                )
            }
        }
    }
}

/** UINavigationController's push: the new screen slides in from the right over the old one, which drifts left. */
private fun pushPop(forward: Boolean): ContentTransform {
    val spec = Theme.Motion.expressive<androidx.compose.ui.unit.IntOffset>()
    return if (forward) {
        slideInHorizontally(spec) { it } togetherWith slideOutHorizontally(spec) { -it / 3 } + fadeOut(tween(250), 0.6f)
    } else {
        slideInHorizontally(spec) { -it / 3 } + fadeIn(tween(250), 0.6f) togetherWith slideOutHorizontally(spec) { it }
    }.also { it.targetContentZIndex = if (forward) 1f else 0f }
}

/**
 * The primary action, and the reason the app exists: a wide ember capsule at the bottom,
 * reachable one-handed. Port of RootView's CaptureButton.
 */
@Composable
private fun CaptureButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val p = palette
    Box(
        modifier
            .fillMaxWidth()
            .padding(horizontal = Theme.Space.lg)
            .padding(bottom = Theme.Space.xs),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .background(p.ember, CircleShape)
                .pressable(label = "Capture", onClick = onClick)
                .padding(vertical = Theme.Space.md)
                .testTag("capture-button"),
            horizontalArrangement = Arrangement.spacedBy(Theme.Space.xs, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SymbolIcon(Symbol.PlusCircleFill, p.canvas, 20.dp)
            Txt("Capture", Theme.Typography.control, p.canvas)
        }
    }
}


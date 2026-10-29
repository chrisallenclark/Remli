package com.chrisallenclark.remli.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.design.LargeTitle
import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.design.SymbolIcon
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.palette

/**
 * A tab whose screen has not been built on Android yet. Says so plainly rather than
 * pretending — the tab bar is here so the app already has the iOS shape.
 */
@Composable
fun PlaceholderTab(title: String, symbol: Symbol, message: String, topInset: Dp, bottomInset: Dp) {
    val p = palette
    Column(Modifier.fillMaxSize().padding(top = topInset, bottom = bottomInset).testTag("placeholder-$title")) {
        LargeTitle(title)
        Column(
            Modifier.weight(1f).fillMaxWidth().padding(horizontal = Theme.Space.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Theme.Space.md, Alignment.CenterVertically),
        ) {
            SymbolIcon(symbol, p.ember, 40.dp)
            Txt("Coming to Android", Theme.Typography.title, p.ink, textAlign = TextAlign.Center)
            Txt(message, Theme.Typography.meta, p.inkMuted, textAlign = TextAlign.Center)
        }
    }
}


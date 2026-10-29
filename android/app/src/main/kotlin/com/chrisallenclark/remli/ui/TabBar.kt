package com.chrisallenclark.remli.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.design.SymbolIcon
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.glass
import com.chrisallenclark.remli.design.palette
import com.chrisallenclark.remli.design.pressable

/** The four places, as on iOS: RootView.swift's TabView. */
enum class Tab(val title: String, val symbol: Symbol, val selectedSymbol: Symbol) {
    Ideas("Ideas", Symbol.SquareStack, Symbol.SquareStackFill),
    Spaces("Spaces", Symbol.SquareGrid2x2, Symbol.SquareGrid2x2Fill),
    Map("Map", Symbol.MapGraph, Symbol.MapGraphFill),
    Roadmaps("Roadmaps", Symbol.Branch, Symbol.BranchFill),
}

/**
 * The iOS 26 tab bar: a frosted capsule floating above the home indicator, the selected tab
 * sitting in a soft lozenge and drawn in the tint colour.
 */
@Composable
fun TabBar(selected: Tab, onSelect: (Tab) -> Unit, modifier: Modifier = Modifier) {
    val p = palette
    Row(
        modifier
            .fillMaxWidth()
            .height(TabBarHeight)
            .glass(CircleShape)
            .padding(4.dp)
            .testTag("tab-bar"),
        horizontalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        Tab.entries.forEach { tab ->
            val isSelected = tab == selected
            val lozenge by animateColorAsState(
                if (isSelected) p.ink.copy(alpha = if (p.isDark) 0.12f else 0.07f) else Color.Transparent,
                Theme.Motion.standard(), label = "tab",
            )
            val tint = if (isSelected) p.ember else p.ink
            Box(
                Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .background(lozenge, CircleShape)
                    .semantics { this.selected = isSelected }
                    .pressable(label = tab.title, role = Role.Tab) { onSelect(tab) },
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    SymbolIcon(if (isSelected) tab.selectedSymbol else tab.symbol, tint, 20.dp)
                    Txt(tab.title, Theme.Typography.tabLabel, tint, maxLines = 1)
                }
            }
        }
    }
}

val TabBarHeight = 62.dp

package com.chrisallenclark.remli.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.chrisallenclark.remli.capabilities.DeviceCapabilities
import com.chrisallenclark.remli.capabilities.SupportTier
import com.chrisallenclark.remli.capabilities.VoiceCapture
import com.chrisallenclark.remli.design.Appearance
import com.chrisallenclark.remli.design.ContinuousShape
import com.chrisallenclark.remli.design.GlassTextButton
import com.chrisallenclark.remli.design.Hairline
import com.chrisallenclark.remli.design.InlineNavBar
import com.chrisallenclark.remli.design.SectionLabel
import com.chrisallenclark.remli.design.Symbol
import com.chrisallenclark.remli.design.SymbolIcon
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.palette
import com.chrisallenclark.remli.design.pressable

/**
 * Settings. Port of SettingsView.swift — the Appearance section, which is A1's.
 *
 * The other iOS sections (fast capture, nudges, free time, quiet hours, engine, Claude)
 * arrive with the features they control; a switch for something that does not exist yet
 * would be a dead control. "This phone" is Android's own: what this device supports and
 * what stands in for what it does not.
 */
@Composable
fun SettingsSheet(
    appearance: Appearance,
    onAppearance: (Appearance) -> Unit,
    capabilities: DeviceCapabilities,
    onDone: () -> Unit,
) {
    val p = palette
    Column(Modifier.fillMaxSize().testTag("settings")) {
        InlineNavBar(
            title = "Settings",
            insetForStatusBar = false,
            trailing = { GlassTextButton("Done", onDone, bold = true) },
        )
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(horizontal = Theme.Space.md, vertical = Theme.Space.sm),
            verticalArrangement = Arrangement.spacedBy(Theme.Space.lg),
        ) {
            FormSection(
                header = "Appearance",
                footer = "The Map stays dark whichever you pick. Its nodes are drawn as light sources, and a glow on white is a smudge.",
            ) {
                val options = Appearance.options(capabilities.followsSystemAppearance)
                options.forEachIndexed { index, option ->
                    if (index > 0) Hairline(Modifier.padding(start = 52.dp))
                    val isSelected = option == appearance ||
                        (!capabilities.followsSystemAppearance && appearance == Appearance.System && option == Appearance.Light)
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .semantics { selected = isSelected }
                            .pressable(label = option.label, role = Role.RadioButton) { onAppearance(option) }
                            .padding(horizontal = Theme.Space.md, vertical = 11.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.width(36.dp)) { SymbolIcon(option.symbol, p.ember, 17.dp) }
                        Txt(option.label, Theme.Typography.body, p.ink, Modifier.weight(1f))
                        if (isSelected) SymbolIcon(Symbol.Checkmark, p.ember, 15.dp)
                    }
                }
            }

            FormSection(
                header = "This phone",
                footer = "What Android ${android.os.Build.VERSION.RELEASE} on this phone supports, and what Remli does instead where it does not.",
            ) {
                capabilityLines(capabilities).forEachIndexed { index, (label, value) ->
                    if (index > 0) Hairline(Modifier.padding(start = Theme.Space.md))
                    Column(Modifier.fillMaxWidth().padding(horizontal = Theme.Space.md, vertical = 10.dp)) {
                        Txt(label, Theme.Typography.body, p.ink)
                        Txt(value, Theme.Typography.meta, p.inkMuted)
                    }
                }
            }
            Spacer(Modifier.size(Theme.Space.lg))
        }
    }
}

/** An inset-grouped form section: small caps header, rounded card of rows, footnote. */
@Composable
private fun FormSection(header: String, footer: String?, content: @Composable () -> Unit) {
    val p = palette
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        SectionLabel(header, Modifier.padding(horizontal = Theme.Space.md))
        Column(Modifier.fillMaxWidth().background(p.surface, ContinuousShape(Theme.Radius.md))) { content() }
        if (footer != null) Txt(footer, Theme.Typography.meta.copy(fontSize = Theme.Typography.sectionLabel.fontSize, lineHeight = Theme.Typography.sectionLabel.lineHeight), p.inkMuted, Modifier.padding(horizontal = Theme.Space.md))
    }
}

/** Plain-language capability lines, shared with tests so the wording is checked too. */
fun capabilityLines(c: DeviceCapabilities): List<Pair<String, String>> = listOf(
    "Support level" to when (c.tier) {
        SupportTier.Polished -> "Full experience"
        SupportTier.Supported -> "Supported, with simpler visual effects"
    },
    "Voice capture" to when (val v = c.voiceCapture) {
        VoiceCapture.PrivateOnDevice -> "Private, on this phone"
        is VoiceCapture.TypingOnly -> when (v.reason) {
            VoiceCapture.Reason.OsTooOld -> "Typing only — this Android version can't keep speech on the phone"
            VoiceCapture.Reason.NoOnDeviceRecognizer -> "Typing only — no private speech recognition on this phone"
        }
    },
    "Frosted glass" to if (c.backdropBlur) "Supported" else "Soft solid panels instead",
    "Follows system light/dark" to if (c.followsSystemAppearance) "Yes" else "Choose Light or Dark above",
    "Performance mode" to if (c.reducedEffects) "Lighter effects for this phone's memory" else "Standard",
)

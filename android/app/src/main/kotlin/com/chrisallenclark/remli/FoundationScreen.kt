package com.chrisallenclark.remli

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chrisallenclark.remli.capabilities.DeviceCapabilities
import com.chrisallenclark.remli.capabilities.SupportTier
import com.chrisallenclark.remli.capabilities.VoiceCapture
import com.chrisallenclark.remli.ui.theme.RemliPalette

/**
 * The A0 screen: proof that the project builds, installs and launches on every supported
 * Android version, and a plain readout of what this phone can do.
 *
 * Temporary. A1 replaces it with the Ideas list. The capability readout moves into
 * Settings, where the iOS app already explains which engine is running and why.
 */
@Composable
fun FoundationScreen(capabilities: DeviceCapabilities, palette: RemliPalette) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.canvas)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        BasicText(
            text = "Remli",
            modifier = Modifier.testTag("title"),
            // Platform serif until A1 bundles the typefaces that stand in for New York.
            style = TextStyle(color = palette.ink, fontSize = 34.sp, fontFamily = FontFamily.Serif),
        )
        BasicText(
            text = "Capture the idea. Find the thread.",
            style = TextStyle(color = palette.inkMuted, fontSize = 17.sp, fontFamily = FontFamily.Serif),
        )
        Spacer(Modifier.height(24.dp))
        BasicText(
            text = "ANDROID FOUNDATION BUILD",
            style = TextStyle(color = palette.inkMuted, fontSize = 13.sp, fontWeight = FontWeight.Medium),
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(palette.surface, RoundedCornerShape(14.dp))
                .border(0.5.dp, palette.hairline, RoundedCornerShape(14.dp))
                .padding(16.dp)
                .testTag("capabilities"),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            capabilityLines(capabilities).forEach { (label, value) ->
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    BasicText(label, style = TextStyle(color = palette.ink, fontSize = 15.sp, fontWeight = FontWeight.Medium))
                    BasicText(value, style = TextStyle(color = palette.inkMuted, fontSize = 15.sp))
                }
            }
        }
    }
}

/** Plain-language lines, shared with tests so the wording is checked, not just the layout. */
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
    "Frosted glass" to if (c.backdropBlur) "Yes" else "Soft solid panels instead",
    "Follows system light/dark" to if (c.followsSystemAppearance) "Yes" else "Choose Light or Dark in Settings",
    "Performance mode" to if (c.reducedEffects) "Lighter effects for this phone's memory" else "Standard",
)

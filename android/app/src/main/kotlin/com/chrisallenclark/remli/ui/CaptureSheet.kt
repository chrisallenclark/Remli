package com.chrisallenclark.remli.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import com.chrisallenclark.remli.design.GlassTextButton
import com.chrisallenclark.remli.design.Hairline
import com.chrisallenclark.remli.design.InlineNavBar
import com.chrisallenclark.remli.design.Theme
import com.chrisallenclark.remli.design.Txt
import com.chrisallenclark.remli.design.palette

/**
 * Capture. Port of CaptureSheet.swift, text half — voice arrives in A2.
 *
 * Nothing stands between a thought and it being saved: no category picker, no tags. The one
 * exception is the name — one quiet, optional line above the body, never focused first.
 * Saving writes the idea immediately; everything clever happens afterwards.
 */
@Composable
fun CaptureSheet(onCancel: () -> Unit, onSave: (text: String, name: String) -> Unit) {
    val p = palette
    var text by rememberSaveable { mutableStateOf("") }
    var name by rememberSaveable { mutableStateOf("") }
    val canSave = text.isNotBlank()
    val body = remember { FocusRequester() }
    val nameFocus = remember { FocusRequester() }

    // The body, never the name. Reaching for the name is a deliberate act.
    LaunchedEffect(Unit) { body.requestFocus() }

    Column(Modifier.fillMaxSize().imePadding().testTag("capture-sheet")) {
        InlineNavBar(
            title = "Capture",
            insetForStatusBar = false,
            leading = { GlassTextButton("Cancel", onCancel) },
            trailing = {
                GlassTextButton(
                    "Save",
                    onClick = { if (canSave) onSave(text.trim(), name.trim()) },
                    bold = true,
                    enabled = canSave,
                    modifier = Modifier.testTag("capture-save"),
                )
            },
        )

        // One line, quiet, above the thought.
        Box(Modifier.fillMaxWidth().padding(horizontal = Theme.Space.lg).padding(top = Theme.Space.xs, bottom = Theme.Space.xs)) {
            // A system TextField placeholder on iOS: lighter than the body's custom one.
            if (name.isEmpty()) Txt("Name it (optional)", Theme.Typography.control, p.ink.copy(alpha = 0.3f))
            BasicTextField(
                value = name,
                onValueChange = { name = it },
                singleLine = true,
                textStyle = Theme.Typography.control.copy(color = p.ink),
                cursorBrush = SolidColor(p.ember),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { body.requestFocus() }),
                modifier = Modifier.fillMaxWidth().focusRequester(nameFocus).testTag("capture-name"),
            )
        }
        Hairline(Modifier.padding(horizontal = Theme.Space.lg))

        Box(Modifier.weight(1f).fillMaxWidth().padding(horizontal = Theme.Space.lg).padding(top = Theme.Space.md)) {
            if (text.isEmpty()) Txt("What's the idea?", Theme.Typography.ideaBody, p.inkMuted)
            BasicTextField(
                value = text,
                onValueChange = { text = it },
                textStyle = Theme.Typography.ideaBody.copy(color = p.ink),
                cursorBrush = SolidColor(p.ember),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                modifier = Modifier.fillMaxSize().focusRequester(body).testTag("capture-body"),
            )
        }
    }
}

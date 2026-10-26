package io.music_assistant.client.ui.compose

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * The iOS root around [App]. It keeps the content out of every side of the safe area, and it
 * consumes those insets, so a screen below it does not pad them again. On iPhone Duo the status
 * bar is a vertical bar at the trailing edge, so the horizontal insets matter as much as the top
 * one. The keyboard is not included, because Compose moves the focused field above it.
 */
@Composable
fun IosAppRoot(content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.systemBars.union(WindowInsets.displayCutout)),
    ) {
        content()
    }
}

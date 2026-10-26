@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

package io.music_assistant.client.ui.compose

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.uikit.LocalUIViewController
import androidx.compose.ui.unit.dp
import kotlinx.cinterop.useContents

/**
 * The iOS root around [App]. It keeps the content out of the part of the safe area that the
 * Compose view covers, and it consumes the safe-area insets, so a screen below it does not pad
 * them again. On iPhone Duo the status bar is a vertical bar at the trailing edge, so the
 * horizontal insets matter as much as the top one. The keyboard is not included, because Compose
 * moves the focused field above it.
 *
 * Compose reports the insets of the whole window, wherever its view is. The SwiftUI shell places
 * the view beside the tab bar or the sidebar, inside the safe area, so those window insets would
 * pad the content a second time. The padding comes from UIKit's `safeAreaInsets` of the view
 * instead, which counts only the unsafe area that the view overlaps.
 */
@Composable
fun IosAppRoot(content: @Composable () -> Unit) {
    val view = LocalUIViewController.current.view
    // Read again whenever the view changes size: folding, rotating or a sidebar resize it.
    val size = LocalWindowInfo.current.containerSize
    // UIKit points are dp, and its left and right are absolute.
    val overlap = remember(view, size) {
        view.safeAreaInsets.useContents {
            PaddingValues.Absolute(left = left.dp, top = top.dp, right = right.dp, bottom = bottom.dp)
        }
    }
    Box(
        Modifier
            .fillMaxSize()
            .consumeWindowInsets(WindowInsets.systemBars.union(WindowInsets.displayCutout))
            .padding(overlap),
    ) {
        content()
    }
}

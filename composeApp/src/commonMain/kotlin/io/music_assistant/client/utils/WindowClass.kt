package io.music_assistant.client.utils

import androidx.compose.material3.adaptive.currentWindowAdaptiveInfoV2
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.window.core.layout.WindowSizeClass

/**
 * The width of the pane that holds this content, when a two-pane layout splits the window. Null
 * when the content has the whole width of the window. [WindowClass] reads it, so a screen in a
 * narrow pane gets its phone layout.
 */
val LocalPaneWidth = compositionLocalOf<Dp?> { null }

object WindowClass {
    /**
     * True when the window is at least medium width, in either orientation. Drives the
     * side-by-side layouts (navigation rail, row-form item header, inline player
     * controls, queue beside the player). A compact-width window keeps the phone layout.
     *
     * Medium width in portrait counts: an unfolded foldable (the iPhone Duo inner
     * display is 669 dp wide) or an iPad mini in portrait has room for a second pane.
     */
    @Composable
    fun isWide(): Boolean = isAtLeastMedium()

    @Composable
    fun isAtLeastMedium(): Boolean =
        isAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_MEDIUM_LOWER_BOUND)

    @Composable
    fun isAtLeastExpanded(): Boolean =
        isAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_EXPANDED_LOWER_BOUND)

    @Composable
    private fun isAtLeastBreakpoint(widthDp: Int): Boolean =
        LocalPaneWidth.current?.let { it >= widthDp.dp }
            ?: currentWindowAdaptiveInfoV2().windowSizeClass.isWidthAtLeastBreakpoint(widthDp)
}

@Composable
fun rowImageSize() = when {
    WindowClass.isAtLeastMedium() -> 48.dp
    else -> 48.dp
}

@Composable
fun libraryItemMinWidth() = when {
    WindowClass.isAtLeastMedium() -> 360.dp
    else -> 240.dp
}

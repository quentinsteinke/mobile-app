package io.music_assistant.client.ui.compose.nav

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import io.music_assistant.client.data.model.client.MediaType

/**
 * Tabs that the platform draws itself around the shared screens, as the SwiftUI tab bar and
 * sidebar on iOS. While one is provided, the main screen publishes its tabs to it and draws no
 * navigation bar or rail of its own. Android provides none.
 */
interface NativeTabShell {
    /**
     * True when the platform also draws the player (mini player, Now Playing and queue) natively.
     * The main screen then draws no player of its own.
     */
    val drawsPlayer: Boolean

    /** Shows [tabs] in the native chrome while the calling screen is composed. */
    @Composable
    fun Publish(tabs: List<NavigationItem>, playerExpanded: Boolean)

    /** Opens the native Now Playing, for a deep link, when [drawsPlayer]. */
    fun expandPlayer() {}

    /**
     * Opens the library list of [mediaType] in a native Library tab, for a deep link. Returns
     * false when the Library tab is not native, so the main screen pushes its own list.
     */
    fun openLibraryList(mediaType: MediaType): Boolean = false
}

val LocalNativeTabShell = staticCompositionLocalOf<NativeTabShell?> { null }

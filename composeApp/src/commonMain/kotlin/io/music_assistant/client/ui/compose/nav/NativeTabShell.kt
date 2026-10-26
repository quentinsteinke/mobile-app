package io.music_assistant.client.ui.compose.nav

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * Tabs that the platform draws itself around the shared screens, as the SwiftUI tab bar and
 * sidebar on iOS. While one is provided, the main screen publishes its tabs to it and draws no
 * navigation bar or rail of its own. Android provides none.
 */
interface NativeTabShell {
    /** Shows [tabs] in the native chrome while the calling screen is composed. */
    @Composable
    fun Publish(tabs: List<NavigationItem>, playerExpanded: Boolean)
}

val LocalNativeTabShell = staticCompositionLocalOf<NativeTabShell?> { null }

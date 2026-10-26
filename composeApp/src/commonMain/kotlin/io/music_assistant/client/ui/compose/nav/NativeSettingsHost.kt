package io.music_assistant.client.ui.compose.nav

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * A platform that draws the settings and connection screen natively (iOS). While the top-level
 * settings screen is composed, it publishes how to leave it for the main screen. Android
 * provides none.
 */
interface NativeSettingsHost {
    @Composable
    fun Publish(goHome: () -> Unit)
}

val LocalNativeSettingsHost = staticCompositionLocalOf<NativeSettingsHost?> { null }

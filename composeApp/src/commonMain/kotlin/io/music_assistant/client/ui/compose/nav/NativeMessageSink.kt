package io.music_assistant.client.ui.compose.nav

import androidx.compose.runtime.staticCompositionLocalOf

/**
 * A platform that shows the app-wide messages (server errors) natively, over native screens
 * that hide the Compose view (iOS). Android provides none, and the Compose toast shows them.
 */
fun interface NativeMessageSink {
    fun show(message: String)
}

val LocalNativeMessageSink = staticCompositionLocalOf<NativeMessageSink?> { null }

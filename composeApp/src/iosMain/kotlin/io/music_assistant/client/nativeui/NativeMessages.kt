package io.music_assistant.client.nativeui

import io.music_assistant.client.ui.compose.nav.NativeMessageSink
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/** The app-wide messages for the native toast, from the Compose error collector. */
object NativeMessages : NativeMessageSink {
    private val _messages = MutableSharedFlow<String>(extraBufferCapacity = 8)
    val messages: SharedFlow<String> = _messages.asSharedFlow()

    override fun show(message: String) {
        _messages.tryEmit(message)
    }
}

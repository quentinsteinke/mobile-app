package io.music_assistant.client.nativeui

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import musicassistantclient.composeapp.generated.resources.Res
import musicassistantclient.composeapp.generated.resources.allStringResources
import org.jetbrains.compose.resources.getString

/**
 * The app strings for the native screens, in the app language, by their key in
 * `composeResources/values/strings.xml`. They load once at start; until then, and for a key
 * without a translation, Swift shows its English text.
 */
object NativeText : NativeScreen() {
    private val texts = MutableStateFlow<Map<String, String>>(emptyMap())

    init {
        scope.launch {
            // A key that only some locales have fails to load in the others; Swift keeps its
            // English text for it.
            texts.value = buildMap {
                Res.allStringResources.forEach { (key, resource) ->
                    runCatching { getString(resource) }.getOrNull()?.let { put(key, it) }
                }
            }
        }
    }

    /** The text of [key], or null before the strings load or for an unknown key. */
    fun text(key: String): String? = texts.value[key]
}

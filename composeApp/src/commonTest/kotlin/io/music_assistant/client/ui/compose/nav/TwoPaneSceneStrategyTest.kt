package io.music_assistant.client.ui.compose.nav

import androidx.navigation3.runtime.NavEntry
import androidx.navigation3.scene.SceneStrategyScope
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class TwoPaneSceneStrategyTest {
    private val home = entry("home")
    private val library = entry("library", TwoPaneSceneStrategy.listPane())
    private val albums = entry("albums")
    private val album = entry("album")

    @Test
    fun `a wide window shows the list beside the top of its stack`() {
        val scene = calculate(enabled = true, listOf(home, library, albums, album))

        assertEquals(listOf(library, album), scene?.entries)
        assertEquals(listOf(home, library, albums), scene?.previousEntries)
    }

    @Test
    fun `a new detail keeps the scene key so the list pane stays in place`() {
        val first = calculate(enabled = true, listOf(home, library, albums))
        val second = calculate(enabled = true, listOf(home, library, albums, album))

        assertEquals(first?.key, second?.key)
    }

    @Test
    fun `the list alone or a stack without a list or a narrow window is not split`() {
        assertNull(calculate(enabled = true, listOf(home, library)))
        assertNull(calculate(enabled = true, listOf(home, albums)))
        assertNull(calculate(enabled = false, listOf(home, library, albums)))
    }

    private fun calculate(enabled: Boolean, entries: List<NavEntry<String>>) =
        with(TwoPaneSceneStrategy<String>(enabled)) { SceneStrategyScope<String>().calculateScene(entries) }

    private fun entry(key: String, metadata: Map<String, Any> = emptyMap()) =
        NavEntry(key, metadata = metadata) {}
}

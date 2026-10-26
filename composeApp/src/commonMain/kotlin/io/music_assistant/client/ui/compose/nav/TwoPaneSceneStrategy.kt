package io.music_assistant.client.ui.compose.nav

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.navigation3.runtime.NavEntry
import androidx.navigation3.scene.Scene
import androidx.navigation3.scene.SceneStrategy
import androidx.navigation3.scene.SceneStrategyScope
import io.music_assistant.client.ui.compose.fold.FoldAwareRow
import io.music_assistant.client.utils.LocalPaneWidth

/**
 * While [enabled], shows the entry marked with [listPane] beside the top entry of the stack above
 * it: the list in the start pane, the detail in the end pane. A book fold splits the panes at the
 * fold (see [FoldAwareRow]). Back pops the detail. The list entry alone, or a stack without one,
 * falls through to the next strategy.
 */
class TwoPaneSceneStrategy<T : Any>(private val enabled: Boolean) : SceneStrategy<T> {
    override fun SceneStrategyScope<T>.calculateScene(entries: List<NavEntry<T>>): Scene<T>? {
        if (!enabled) return null
        val listIndex = entries.indexOfLast { LIST_PANE_KEY in it.metadata }
        if (listIndex == -1 || listIndex == entries.lastIndex) return null
        return TwoPaneScene(list = entries[listIndex], detail = entries.last(), previousEntries = entries.dropLast(1))
    }

    companion object {
        private const val LIST_PANE_KEY = "TwoPaneSceneStrategy.listPane"

        /** Metadata for the entry that stays in the start pane. */
        fun listPane(): Map<String, Any> = mapOf(LIST_PANE_KEY to true)
    }
}

object TwoPaneSemantics {
    const val LIST_PANE_TAG = "two_pane_list"
    const val DETAIL_PANE_TAG = "two_pane_detail"
}

private class TwoPaneScene<T : Any>(
    private val list: NavEntry<T>,
    private val detail: NavEntry<T>,
    override val previousEntries: List<NavEntry<T>>,
) : Scene<T> {
    // Keyed by the list alone: a new detail replaces the old one in place, and the list pane
    // does not slide out and back in with it.
    override val key: Any = TwoPaneSceneKey(list.contentKey)

    override val entries: List<NavEntry<T>> = listOf(list, detail)

    override val content: @Composable () -> Unit = {
        FoldAwareRow(
            modifier = Modifier.fillMaxSize(),
            startWidth = ::listPaneWidth,
            spacing = 1.dp,
            divider = { VerticalDivider() },
            start = { Pane(TwoPaneSemantics.LIST_PANE_TAG) { list.Content() } },
            end = { Pane(TwoPaneSemantics.DETAIL_PANE_TAG) { detail.Content() } },
        )
    }

    override fun equals(other: Any?): Boolean =
        other is TwoPaneScene<*> && list == other.list && detail == other.detail &&
            previousEntries == other.previousEntries

    override fun hashCode(): Int = (list.hashCode() * 31 + detail.hashCode()) * 31 + previousEntries.hashCode()
}

private data class TwoPaneSceneKey(val listContentKey: Any)

/** A list wide enough for its labels, and the rest for the detail. */
private fun listPaneWidth(maxWidth: Dp): Dp = (maxWidth * LIST_PANE_FRACTION).coerceIn(240.dp, 360.dp)

private const val LIST_PANE_FRACTION = 0.4f

/** A pane tells its content its own width, so a screen in a narrow pane gets its phone layout. */
@Composable
private fun Pane(tag: String, content: @Composable () -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize().testTag(tag)) {
        CompositionLocalProvider(LocalPaneWidth provides maxWidth, content)
    }
}

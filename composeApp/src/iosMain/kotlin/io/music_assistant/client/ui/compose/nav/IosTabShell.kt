package io.music_assistant.client.ui.compose.nav

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import io.music_assistant.client.ui.theme.sfSymbolName
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** A tab of the SwiftUI shell. [symbol] is the SF Symbol of its icon. */
data class ShellTab(val title: String, val symbol: String)

/**
 * What the SwiftUI shell shows. [active] is true while the main screen is composed, so the shell
 * shows the tabs; otherwise (the settings and connection screen) it shows the Compose view alone.
 */
data class TabShellState(
    val active: Boolean,
    val tabs: List<ShellTab>,
    val selected: Int,
    val playerExpanded: Boolean,
)

/**
 * The bridge between the main screen and the SwiftUI `TabView` in `ContentView.swift`. The main
 * screen publishes its tabs here, Swift reads [state] (through `KmpHelper.observeTabShell`) and
 * sends tab taps back to [select]. The tab switch itself stays in Kotlin, so the back stacks, the
 * deep links and the "back to Home" behaviour do not change.
 */
object IosTabShell : NativeTabShell {
    /** The SwiftUI shell draws the mini player, Now Playing and the queue (`NativePlayer`). */
    override val drawsPlayer: Boolean = true

    private val mutableState = MutableStateFlow(inactive)
    val state: StateFlow<TabShellState> = mutableState.asStateFlow()

    private var tabs: List<NavigationItem> = emptyList()
    private var owner: Any? = null

    @Composable
    override fun Publish(tabs: List<NavigationItem>, playerExpanded: Boolean) {
        val token = remember { Any() }
        SideEffect {
            owner = token
            this.tabs = tabs
            mutableState.value = TabShellState(
                active = true,
                tabs = tabs.map { ShellTab(it.label.orEmpty(), sfSymbolName(it.icon) ?: FALLBACK_SYMBOL) },
                selected = tabs.indexOfFirst { it.selected }.coerceAtLeast(0),
                playerExpanded = playerExpanded,
            )
        }
        DisposableEffect(token) {
            onDispose {
                // A newer main screen may have published already; only the current one resets.
                if (owner === token) {
                    owner = null
                    this@IosTabShell.tabs = emptyList()
                    mutableState.value = inactive
                }
            }
        }
    }

    /** A tap on tab [index]. A tap on the open tab returns it to its root, as in Compose. */
    fun select(index: Int) {
        tabs.getOrNull(index)?.onClick?.invoke()
    }
}

private val inactive = TabShellState(active = false, tabs = emptyList(), selected = 0, playerExpanded = false)

private const val FALLBACK_SYMBOL = "circle"

package io.music_assistant.client.nativeui

import io.music_assistant.client.data.model.client.QueueOption
import io.music_assistant.client.data.model.client.items.RecommendationFolder
import io.music_assistant.client.data.play.PlayMode
import io.music_assistant.client.ui.compose.common.DataState
import io.music_assistant.client.ui.compose.library.AiRadioViewModel
import io.music_assistant.client.ui.compose.library.BrowseViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import org.koin.core.component.get
import org.koin.core.parameter.parametersOf

/** One level of Browse: the providers at the root, then their folders and items. */
data class NativeBrowseState(val load: NativeLoad, val items: List<NativeMediaItem>)

/** One level of the server's Browse tree at [path], or the root when [path] is null. */
class NativeBrowse(path: String?) : NativeScreen() {
    private val browse = viewModel { get<BrowseViewModel> { parametersOf(path) } }

    val state: StateFlow<NativeBrowseState> = browse.state
        .map { state ->
            // The server's ".." entry is the parent level, which the native back button opens.
            val items = state.dataOrNull.orEmpty().filterNot { (it as? RecommendationFolder)?.isParentLink == true }
            NativeBrowseState(
                load = when (state) {
                    is DataState.Loading -> NativeLoad.LOADING
                    is DataState.Error -> NativeLoad.ERROR
                    else -> if (items.isEmpty()) NativeLoad.EMPTY else NativeLoad.LOADED
                },
                items = items.map { it.toNative() },
            )
        }
        .stateIn(scope, SharingStarted.Eagerly, NativeBrowseState(NativeLoad.LOADING, emptyList()))

    fun reload() = browse.load()

    fun play(item: NativeMediaItem) = browse.onPlayClick(item.item, PlayMode(QueueOption.REPLACE))
}

/** An AI Radio station, which plays like a radio. */
data class NativeAiStation(val id: String, val name: String, val artworkUrl: String?)

data class NativeAiRadioState(
    val load: NativeLoad,
    val stations: List<NativeAiStation>,
    /** False while no player is selected, so a station has nowhere to play. */
    val hasTargetPlayer: Boolean,
)

/** The AI Radio stations of the server. */
class NativeAiRadio : NativeScreen() {
    private val radio = viewModel { get<AiRadioViewModel>() }

    val state: StateFlow<NativeAiRadioState> = combine(radio.state, radio.hasTargetPlayer) { state, hasPlayer ->
        when (state) {
            AiRadioViewModel.State.Loading -> NativeAiRadioState(NativeLoad.LOADING, emptyList(), hasPlayer)
            AiRadioViewModel.State.Failed -> NativeAiRadioState(NativeLoad.ERROR, emptyList(), hasPlayer)
            is AiRadioViewModel.State.Ready -> NativeAiRadioState(
                load = if (state.stations.isEmpty()) NativeLoad.EMPTY else NativeLoad.LOADED,
                stations = state.stations.map { NativeAiStation(it.id, it.name, state.artwork[it.id]) },
                hasTargetPlayer = hasPlayer,
            )
        }
    }.stateIn(scope, SharingStarted.Eagerly, NativeAiRadioState(NativeLoad.LOADING, emptyList(), true))

    init {
        radio.load()
    }

    fun reload() = radio.load()

    fun play(stationId: String) {
        (radio.state.value as? AiRadioViewModel.State.Ready)?.stations
            ?.firstOrNull { it.id == stationId }
            ?.let { radio.play(it) }
    }
}

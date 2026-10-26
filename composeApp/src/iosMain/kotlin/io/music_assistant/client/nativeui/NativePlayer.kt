package io.music_assistant.client.nativeui

import io.music_assistant.client.data.MainDataSource
import io.music_assistant.client.data.model.client.ImageType
import io.music_assistant.client.data.model.client.MediaType
import io.music_assistant.client.data.model.client.PlayerData
import io.music_assistant.client.data.model.client.QueueTrack
import io.music_assistant.client.data.model.client.RepeatMode
import io.music_assistant.client.data.model.client.items.AppMediaItem
import io.music_assistant.client.data.model.client.items.AudioSource
import io.music_assistant.client.data.model.client.items.Audiobook
import io.music_assistant.client.data.model.client.items.LongFormSeekDefaults
import io.music_assistant.client.data.model.client.items.canBeFavorited
import io.music_assistant.client.data.model.client.items.image
import io.music_assistant.client.data.model.client.items.isLongFormSpokenContent
import io.music_assistant.client.data.model.client.navigationChapters
import io.music_assistant.client.ui.compose.common.action.PlayerAction
import io.music_assistant.client.ui.compose.common.action.QueueAction
import io.music_assistant.client.ui.compose.common.viewmodel.ActionsViewModel
import io.music_assistant.client.ui.compose.home.HomeScreenViewModel
import io.music_assistant.client.ui.compose.home.selectedPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/** A player that the user can switch the native player UI to. */
data class NativePlayerChoice(
    val playerId: String,
    val name: String,
    val isPlaying: Boolean,
    val isSelected: Boolean,
    val isLocal: Boolean,
)

/** One row of the queue in the native queue list. */
data class NativeQueueItem(
    val queueItemId: String,
    val title: String,
    val subtitle: String?,
    val artworkUrl: String?,
    val durationSec: Double?,
    val isCurrent: Boolean,
    val isPlayable: Boolean,
)

/**
 * Everything the native mini player and Now Playing screen show for the selected player. The
 * enablement rules match the Compose player controls (`PlayerControls`, `FullPlayerItem`).
 */
data class NativeNowPlaying(
    val playerId: String,
    val playerName: String,
    val isLocal: Boolean,
    val queueId: String?,
    val queueItemId: String?,
    val title: String?,
    val subtitle: String?,
    val artworkUrl: String?,
    val durationSec: Double?,
    val elapsedSec: Double?,
    val isPlaying: Boolean,
    /** The main button stops instead of pausing (radio and other content that cannot pause). */
    val showsStop: Boolean,
    val isPending: Boolean,
    val isPoweredOff: Boolean,
    val isSeekable: Boolean,
    val isLongForm: Boolean,
    val canPlay: Boolean,
    val canPrevious: Boolean,
    val canNext: Boolean,
    val shuffleEnabled: Boolean,
    val canShuffle: Boolean,
    val repeatMode: RepeatMode?,
    val canRepeat: Boolean,
    val volume: Float?,
    val canSetVolume: Boolean,
    val isMuted: Boolean,
    val favorite: Boolean?,
    val canFavorite: Boolean,
    val queue: List<NativeQueueItem>,
)

/** The state of the native player UI. [current] is null while no player is available. */
data class NativePlayerState(
    val players: List<NativePlayerChoice>,
    val current: NativeNowPlaying?,
)

/**
 * The bridge for the native SwiftUI player (mini player, Now Playing, queue). It reuses
 * [HomeScreenViewModel] for the player list, the selection and the actions, so the native UI
 * behaves as the Compose player does. One instance lives for the app's lifetime.
 */
object NativePlayer : KoinComponent {
    private val viewModel: HomeScreenViewModel by inject()
    private val actions: ActionsViewModel by inject()
    private val dataSource: MainDataSource by inject()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var selected: PlayerData? = null

    val state: StateFlow<NativePlayerState> = combine(
        viewModel.playersState,
        viewModel.chapterProgressEnabled,
        dataSource.grantedScopes,
    ) { players, chapterProgress, scopes ->
        val data = players as? HomeScreenViewModel.PlayersState.Data
        val current = data?.selectedPlayer
        selected = current
        NativePlayerState(
            players = data?.playerData.orEmpty().map {
                NativePlayerChoice(
                    playerId = it.playerId,
                    name = it.player.nameAndSuffix,
                    isPlaying = it.player.isPlaying,
                    isSelected = it.playerId == current?.playerId,
                    isLocal = it.isLocal,
                )
            },
            current = current?.toNowPlaying(chapterProgress, scopes.canEditLibrary),
        )
    }.stateIn(scope, SharingStarted.Eagerly, NativePlayerState(emptyList(), null))

    /** Elapsed seconds of [queueId], ticking while it plays. */
    fun position(queueId: String): Flow<Double> = viewModel.observePosition(queueId)

    fun togglePlayPause() = act { data ->
        when {
            data.pendingPlay && !data.player.isPlaying -> PlayerAction.Pause
            data.player.isPlaying && !data.canPauseContent -> PlayerAction.Stop
            else -> PlayerAction.TogglePlayPause
        }
    }

    fun next() = act { PlayerAction.Next }

    fun previous() = act { PlayerAction.Previous }

    fun skipBack() = act { PlayerAction.SeekBy(-LongFormSeekDefaults.BACK_SECONDS) }

    fun skipForward() = act { PlayerAction.SeekBy(LongFormSeekDefaults.FORWARD_SECONDS) }

    fun seek(seconds: Double) = act { PlayerAction.SeekTo(seconds.toLong()) }

    fun toggleShuffle() = act { data ->
        data.queueInfo?.let { PlayerAction.ToggleShuffle(current = it.shuffleEnabled) }
    }

    fun toggleRepeat() = act { data ->
        data.queueInfo?.repeatMode?.let { PlayerAction.ToggleRepeatMode(current = it) }
    }

    fun setVolume(level: Double) = act { data ->
        if (data.isGroupBound) PlayerAction.GroupVolumeSet(level) else PlayerAction.VolumeSet(level)
    }

    fun toggleMute() = act { data ->
        val muted = data.player.currentMuteState
        if (data.isGroupBound) PlayerAction.GroupToggleMute(muted) else PlayerAction.ToggleMute(muted)
    }

    fun powerOn() = act { PlayerAction.SetPower(true) }

    fun selectPlayer(id: String) {
        val data = viewModel.playersState.value as? HomeScreenViewModel.PlayersState.Data ?: return
        data.playerData.firstOrNull { it.playerId == id }?.let { viewModel.selectPlayer(it.player) }
    }

    /** Like, or take the like back. The dislike choice stays in the Compose menus for now. */
    fun toggleFavorite() {
        val item = selected?.queueInfo?.currentItem?.track as? AppMediaItem ?: return
        actions.onFavoriteChange(item, if (item.favorite == true) null else true)
    }

    fun playQueueItem(queueItemId: String) = queue { QueueAction.PlayQueueItem(it, queueItemId) }

    fun removeQueueItem(queueItemId: String) = queue { QueueAction.RemoveItems(it, listOf(queueItemId)) }

    fun moveQueueItem(queueItemId: String, from: Int, to: Int) =
        queue { QueueAction.MoveItem(it, queueItemId, from = from, to = to) }

    fun clearQueue() = queue { QueueAction.ClearQueue(it) }

    private fun act(action: (PlayerData) -> PlayerAction?) {
        val data = selected ?: return
        action(data)?.let { viewModel.playerAction(data, it) }
    }

    private fun queue(action: (String) -> QueueAction) {
        selected?.queueId?.let { viewModel.queueAction(action(it)) }
    }
}

private val PlayerData.isGroupBound: Boolean get() = childrenBinds.any { it.isBound }

private fun PlayerData.toNowPlaying(chapterProgress: Boolean, canEditLibrary: Boolean): NativeNowPlaying {
    val media = player.currentMedia
    val queue = queueInfo
    val current = queue?.currentItem
    val track = current?.track
    val items = queueItems.orEmpty()
    val enabled = player.canPlay && !player.isAnnouncing
    val playable = current?.isPlayable == true
    val isLiveInput = track is AudioSource
    val duration = if (player.isPoweredOff) null else media?.duration?.takeIf { it > 0 }
    val elapsed = queue?.elapsedTime ?: 0.0
    val hasUpcomingChapter = chapterProgress && track.navigationChapters()?.any { it.start > elapsed } == true
    val canSkipForward = when {
        queue?.currentIndex?.let { it < items.size - 1 } == true -> true
        hasUpcomingChapter -> true
        (track as? Audiobook)?.fullyPlayed == false -> true
        else -> false
    }
    val item = track as? AppMediaItem
    return NativeNowPlaying(
        playerId = playerId,
        playerName = player.nameAndSuffix,
        isLocal = isLocal,
        queueId = queue?.id,
        queueItemId = current?.id,
        title = media?.title ?: track?.displayName,
        subtitle = media?.subtitle ?: track?.subtitle,
        artworkUrl = media?.imageUrl ?: track?.image(ImageType.THUMB)?.url,
        durationSec = duration,
        elapsedSec = queue?.elapsedTime,
        isPlaying = player.isPlaying,
        showsStop = player.isPlaying && !canPauseContent,
        isPending = pendingPlay && !player.isPlaying,
        isPoweredOff = player.isPoweredOff,
        isSeekable = duration != null && media?.mediaType != MediaType.RADIO,
        isLongForm = track.isLongFormSpokenContent,
        canPlay = enabled,
        canPrevious = enabled && playable,
        canNext = enabled && playable && canSkipForward,
        shuffleEnabled = queue?.shuffleEnabled == true,
        canShuffle = enabled && playable && queue != null && !queue.isDynamicPlaylist && !isLiveInput,
        repeatMode = queue?.repeatMode,
        canRepeat = enabled && playable && queue?.repeatMode != null && queue.isDynamicPlaylist.not() && !isLiveInput,
        volume = player.currentVolume,
        canSetVolume = player.isVolumeSliderAccessible,
        isMuted = player.currentMuteState,
        favorite = item?.favorite,
        canFavorite = canEditLibrary && item?.canBeFavorited == true,
        queue = items.map { it.toNative(isCurrent = it.id == current?.id) },
    )
}

private fun QueueTrack.toNative(isCurrent: Boolean) = NativeQueueItem(
    queueItemId = id,
    title = track.displayName,
    subtitle = track.subtitle,
    artworkUrl = track.image(ImageType.THUMB)?.url,
    durationSec = track.duration,
    isCurrent = isCurrent,
    isPlayable = isPlayable,
)

package io.music_assistant.client.nativeui

import io.music_assistant.client.data.MainDataSource
import io.music_assistant.client.data.announcement.AnnouncementOptions
import io.music_assistant.client.data.announcement.AnnouncementRepository
import io.music_assistant.client.data.announcement.LiveRecording
import io.music_assistant.client.data.model.client.PlayerData
import io.music_assistant.client.data.model.client.items.description
import io.music_assistant.client.data.repository.QueueOverlayRepository
import io.music_assistant.client.ui.compose.home.HomeScreenViewModel
import io.music_assistant.client.ui.compose.home.players.DspSettingsViewModel
import io.music_assistant.client.ui.compose.home.players.QueueDjViewModel
import io.music_assistant.client.ui.compose.home.players.menuFor
import io.music_assistant.client.ui.compose.home.selectedPlayer
import io.music_assistant.client.ui.compose.provider.ProviderViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import org.koin.core.component.get

/** One stage of the audio chain: where the audio comes from, or a player it goes to. */
data class NativeStreamStage(val name: String?, val format: String?)

/** The stream details of the current item, as the Compose audio chain dialog shows them. */
data class NativeStreamDetails(
    val input: NativeStreamStage,
    /** The container the item plays from (server 2.11), when it has a detail page. */
    val origin: NativeMediaItem?,
    val outputs: List<NativeStreamStage>,
)

/** The ambient sound of the queue. */
data class NativeOverlay(val enabled: Boolean, val sourceUri: String?, val sourceName: String?, val volume: Int)

data class NativeSound(val uri: String, val name: String)

data class NativeDjHost(val id: String, val name: String)

/** The DSP of a player: on or off, and the presets, with the one that is applied. */
data class NativeDsp(
    val load: NativeLoad,
    val enabled: Boolean,
    val presets: List<String>,
    val appliedPreset: String?,
)

/**
 * The player tools of the selected player, each null or false while it does not apply, with
 * the gates of the Compose player page.
 */
data class NativeTools(
    val playerId: String?,
    val stream: NativeStreamDetails?,
    val canConfigureDsp: Boolean,
    val canAnnounceText: Boolean,
    val canAnnounceVoice: Boolean,
    val overlay: NativeOverlay?,
    /** Null hides the queue DJ (no AI Radio, or no queue). */
    val djHosts: List<NativeDjHost>?,
    val djHostId: String?,
)

/**
 * The bridge for the player tools of native Now Playing: stream details, DSP, announcements,
 * the ambient sound and the AI Radio queue DJ. One for the app's lifetime.
 */
object NativePlayerTools : NativeScreen() {
    // The player bridge's view model, so both follow the same selection.
    private val home: HomeScreenViewModel get() = NativePlayer.viewModel
    private val dataSource: MainDataSource = get()
    private val announcements: AnnouncementRepository = get()
    private val overlays: QueueOverlayRepository = get()
    private val queueDj = viewModel { get<QueueDjViewModel>() }
    private val dsp = viewModel { get<DspSettingsViewModel>() }
    private val providers = viewModel { get<ProviderViewModel>() }

    private val selected = home.playersState.map { (it as? HomeScreenViewModel.PlayersState.Data)?.selectedPlayer }

    val state: StateFlow<NativeTools> = combine(
        selected,
        dataSource.grantedScopes,
        announcements.availability,
        overlays.available,
        queueDj.state,
    ) { player, scopes, announce, overlayAvailable, dj ->
        val queueId = player?.queueId
        val djMenu = queueId?.let { dj?.menuFor(it) }
        NativeTools(
            playerId = player?.playerId,
            stream = player?.streamDetails(),
            canConfigureDsp = player != null && !player.player.isGroup && scopes.canConfigurePlayers,
            canAnnounceText = player != null && announce.text,
            canAnnounceVoice = player != null && announce.voice && !player.isLocal,
            overlay = player?.queueInfo?.overlay?.takeIf { overlayAvailable }
                ?.let { NativeOverlay(it.enabled, it.sourceUri, it.sourceName, it.volume) },
            djHosts = djMenu?.hosts?.map { NativeDjHost(it.id, it.name) },
            djHostId = djMenu?.selectedHostId,
        )
    }.stateIn(scope, SharingStarted.Eagerly, NativeTools(null, null, false, false, false, null, null, null))

    private fun PlayerData.streamDetails(): NativeStreamDetails? {
        // Nothing to show until the server has the stream details, as in the Compose player.
        val item = queueInfo?.currentItem?.takeIf { it.format != null || it.audioProcessingChain != null } ?: return null
        val names = buildMap {
            put(playerId, player.nameAndSuffix)
            childrenBinds.forEach { put(it.id, it.name) }
            parentBind?.let { put(it.id, it.name) }
        }
        return NativeStreamDetails(
            input = NativeStreamStage(
                name = item.provider?.let { providers.getProviderDetails(it)?.name },
                format = item.format?.description,
            ),
            origin = item.origin?.toNative()?.takeIf { it.opensDetails },
            outputs = item.audioProcessingChain?.outputs.orEmpty().map { output ->
                NativeStreamStage(
                    name = output.playerIds?.firstOrNull()?.let { names[it] },
                    format = output.format?.description,
                )
            },
        )
    }

    // DSP

    val dspState: StateFlow<NativeDsp> = dsp.state.map { state ->
        when (state) {
            is DspSettingsViewModel.DspDialogState.Loading -> NativeDsp(NativeLoad.LOADING, false, emptyList(), null)
            is DspSettingsViewModel.DspDialogState.Error -> NativeDsp(NativeLoad.ERROR, false, emptyList(), null)
            is DspSettingsViewModel.DspDialogState.Content -> NativeDsp(
                load = NativeLoad.LOADED,
                enabled = state.config.enabled,
                presets = state.presets.map { it.name },
                appliedPreset = state.appliedPresetKey?.second,
            )
        }
    }.stateIn(scope, SharingStarted.Eagerly, NativeDsp(NativeLoad.LOADING, false, emptyList(), null))

    fun loadDsp() {
        state.value.playerId?.let { dsp.load(it) }
    }

    fun toggleDsp() {
        state.value.playerId?.let { dsp.toggleEnabled(it) }
    }

    fun applyDspPreset(index: Int) {
        val playerId = state.value.playerId ?: return
        val presets = (dsp.state.value as? DspSettingsViewModel.DspDialogState.Content)?.presets ?: return
        presets.getOrNull(index)?.let { dsp.applyPreset(playerId, it) }
    }

    // Announcements

    /** The player's chime setting, or null when the server does not say. */
    suspend fun announcementChime(): Boolean? = state.value.playerId?.let { announcements.chimeSetting(it) }

    /** Speaks [message] on the selected player. A null [volume] keeps the player's own level. */
    fun announce(message: String, chime: Boolean, volume: Int?) {
        val playerId = state.value.playerId ?: return
        announcements.type(playerId, message, AnnouncementOptions(preAnnounce = chime, volumeLevel = volume))
    }

    /** Starts a spoken announcement from the microphone. Finish the recording to send it. */
    fun speak(chime: Boolean, volume: Int?): LiveRecording? = state.value.playerId?.let {
        announcements.speak(it, AnnouncementOptions(preAnnounce = chime, volumeLevel = volume))
    }

    // Ambient sound

    suspend fun sounds(): List<NativeSound> = overlays.soundEffects().getOrNull().orEmpty()
        .mapNotNull { sound -> sound.uri?.let { NativeSound(it, sound.name) } }

    /** Plays [uri] at [volume] over the queue, or turns the sound off when [uri] is null. */
    fun setOverlay(uri: String?, volume: Int) {
        val queueId = home.playersState.value.let { it as? HomeScreenViewModel.PlayersState.Data }
            ?.selectedPlayer?.queueId ?: return
        overlays.apply(queueId, uri, volume)
    }

    // Queue DJ

    /** Sets the AI Radio host of the queue, or turns the DJ off when [hostId] is null. */
    fun selectDj(hostId: String?) {
        val queueId = home.playersState.value.let { it as? HomeScreenViewModel.PlayersState.Data }
            ?.selectedPlayer?.queueId ?: return
        queueDj.select(queueId, hostId)
    }
}

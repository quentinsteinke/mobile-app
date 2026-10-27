package io.music_assistant.client.nativeui

import io.music_assistant.client.api.ServiceClient
import io.music_assistant.client.ui.compose.common.BannerState
import io.music_assistant.client.ui.compose.common.reconnectionBannerState
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.mapLatest
import kotlinx.coroutines.flow.stateIn
import musicassistantclient.composeapp.generated.resources.Res
import musicassistantclient.composeapp.generated.resources.banner_no_network
import musicassistantclient.composeapp.generated.resources.banner_reconnecting
import org.jetbrains.compose.resources.getString
import org.koin.core.component.get

/**
 * The reconnect banner of the native shell, with the rules of the Compose banner
 * (`ConnectionStatusOverlay`): the text while the session reconnects or waits for the network,
 * null otherwise.
 */
@OptIn(ExperimentalCoroutinesApi::class)
object NativeConnection : NativeScreen() {
    private val serviceClient: ServiceClient = get()

    val banner: StateFlow<String?> = serviceClient.sessionState
        .mapLatest { state ->
            when (val banner = reconnectionBannerState(state)) {
                is BannerState.Reconnecting -> getString(Res.string.banner_reconnecting, banner.attempt)
                BannerState.NoNetwork -> getString(Res.string.banner_no_network)
                null -> null
            }
        }
        .stateIn(scope, SharingStarted.Eagerly, null)

    /** Stops reconnecting, as the banner's Stop button does in Compose. */
    fun stop() = serviceClient.disconnectByUser()
}

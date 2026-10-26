package io.music_assistant.client.nativeui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import io.music_assistant.client.api.ConnectionInfo
import io.music_assistant.client.auth.AuthState
import io.music_assistant.client.data.model.server.AuthProvider
import io.music_assistant.client.settings.ConnectionHistoryEntry
import io.music_assistant.client.settings.ConnectionType
import io.music_assistant.client.settings.SettingsRepository
import io.music_assistant.client.ui.compose.auth.AuthenticationViewModel
import io.music_assistant.client.ui.compose.nav.NativeSettingsHost
import io.music_assistant.client.ui.compose.settings.SendspinSettingsViewModel
import io.music_assistant.client.ui.compose.settings.SettingsViewModel
import io.music_assistant.client.ui.theme.ThemeSetting
import io.music_assistant.client.ui.theme.ThemeViewModel
import io.music_assistant.client.utils.DataConnectionState
import io.music_assistant.client.utils.SessionState
import io.music_assistant.sendspin.api.AudioCodec
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.mapLatest
import kotlinx.coroutines.flow.stateIn
import org.jetbrains.compose.resources.getString
import org.koin.core.component.get

/** Where the connection to the server is. */
enum class NativeSessionPhase { DISCONNECTED, CONNECTING, AWAITING_AUTH, SIGNED_IN }

/** A way to sign in that the server offers: its own accounts, or Home Assistant. */
data class NativeAuthProvider(val providerId: String, val isBuiltin: Boolean, val isHomeAssistant: Boolean)

/** A server that the app connected to before. */
data class NativeHistoryEntry(
    val historyKey: String,
    val title: String,
    val subtitle: String,
    val isWebRtc: Boolean,
    val host: String?,
    val port: Int?,
    val isTls: Boolean,
    val basePath: String,
    val remoteId: String?,
)

/** The local (Sendspin) player settings being edited. */
data class NativeLocalPlayer(
    val enabled: Boolean,
    val name: String,
    val codecName: String,
    val codecNames: List<String>,
    val hiRes: Boolean,
    val hiResAvailable: Boolean,
    val bufferSeconds: Int,
    val isSavable: Boolean,
    val isResettable: Boolean,
    val isConfirmationPending: Boolean,
)

data class NativeSettingsState(
    val phase: NativeSessionPhase,
    val usesWebRtc: Boolean,
    val savedHost: String,
    val savedPort: String,
    val savedTls: Boolean,
    val savedBasePath: String,
    val webrtcRemoteId: String,
    val connectInFlight: Boolean,
    val connectingTo: String?,
    val errorMessage: String?,
    val serverName: String?,
    val serverAddress: String?,
    val serverVersion: String?,
    val userDescription: String?,
    val authProviders: List<NativeAuthProvider>,
    val authBusy: Boolean,
    val authError: String?,
    val themeName: String,
    val allowLandscape: Boolean,
    val localPlayer: NativeLocalPlayer,
    val history: List<NativeHistoryEntry>,
    val appVersion: String,
    val isPreparingShare: Boolean,
    val localNetworkTitle: String?,
    val localNetworkBody: String?,
)

/**
 * The native settings and connection screen, over [SettingsViewModel],
 * [AuthenticationViewModel], [ThemeViewModel] and [SendspinSettingsViewModel].
 */
@OptIn(ExperimentalCoroutinesApi::class)
class NativeSettings : NativeScreen() {
    private val settings = viewModel { get<SettingsViewModel>() }
    private val auth = viewModel { get<AuthenticationViewModel>() }
    private val theme = viewModel { get<ThemeViewModel>() }
    private val player = viewModel { get<SendspinSettingsViewModel>() }

    private val connection: Flow<ConnectionPart> = combine(
        settings.sessionState,
        settings.savedConnectionInfo,
        settings.preferredConnectionMethod,
        settings.webrtcRemoteId,
        settings.connectAttemptInFlight,
    ) { session, saved, method, remoteId, inFlight ->
        ConnectionPart(session, saved, method == WEBRTC, remoteId, inFlight)
    }

    private val guidance: Flow<GuidancePart> = combine(
        settings.localNetworkBlocked,
        settings.lastLocalNetworkProbeGranted,
        settings.connectionHistory,
        settings.localNetworkOnboardingShown,
        settings.isPreparingShare,
    ) { blocked, probe, history, onboardingShown, preparing ->
        GuidancePart(blocked, probe, history, onboardingShown, preparing)
    }

    private val account: Flow<AccountPart> = combine(
        auth.authState,
        auth.providers,
        theme.theme,
        settings.allowLandscapeOnAllDevices,
    ) { authState, providers, themeSetting, landscape ->
        AccountPart(authState, providers, themeSetting, landscape)
    }

    private val localPlayer: Flow<NativeLocalPlayer> = combine(
        player.enabled,
        player.draft,
        player.isSavable,
        player.isResettable,
        player.isConfirmationPending,
    ) { enabled, draft, savable, resettable, pending ->
        NativeLocalPlayer(
            enabled = enabled,
            name = draft.name,
            codecName = draft.codecPreference.name,
            codecNames = SettingsRepository.CODECS.map { it.name },
            hiRes = draft.effectiveBitDepth() == SettingsRepository.BIT_DEPTH_HI_RES,
            hiResAvailable = draft.hiResAvailable(),
            bufferSeconds = draft.bufferSeconds,
            isSavable = savable,
            isResettable = resettable,
            isConfirmationPending = pending,
        )
    }

    val state: StateFlow<NativeSettingsState> = combine(connection, guidance, account, localPlayer) { c, g, a, p ->
        Parts(c, g, a, p)
    }.mapLatest { parts -> parts.toState() }
        .stateIn(scope, SharingStarted.Eagerly, initialState)

    fun setUsesWebRtc(enabled: Boolean) = settings.setPreferredConnectionMethod(if (enabled) WEBRTC else DIRECT)

    fun connect(host: String, port: String, isTls: Boolean, basePath: String) =
        settings.attemptConnection(host.ifBlank { DEFAULT_HOST }, port, isTls, basePath)

    fun setWebrtcRemoteId(remoteId: String) = settings.setWebrtcRemoteId(remoteId.uppercase())

    fun connectWebRtc() = settings.attemptWebRTCConnection(settings.webrtcRemoteId.value)

    /** Cancels a connection attempt, or disconnects. */
    fun disconnect() = settings.disconnect()

    fun signIn(providerId: String, username: String, password: String) {
        val provider = auth.providers.value.firstOrNull { it.id == providerId } ?: return
        auth.username.value = username
        auth.password.value = password
        auth.login(provider)
    }

    /** Opens the browser sign-in of a provider (Home Assistant). */
    fun signInWithBrowser(providerId: String) {
        auth.providers.value.firstOrNull { it.id == providerId }?.let(auth::login)
    }

    fun retryProviders() = auth.loadProviders()

    fun signOut() = settings.logout()

    fun setTheme(name: String) {
        ThemeSetting.entries.firstOrNull { it.name == name }?.let(theme::switchTheme)
    }

    fun setAllowLandscape(enabled: Boolean) = settings.setAllowLandscapeOnAllDevices(enabled)

    fun setLocalPlayerEnabled(enabled: Boolean) = player.setEnabled(enabled)

    fun setLocalPlayerName(name: String) = player.update { it.copy(name = name) }

    fun setLocalPlayerCodec(name: String) {
        val codec = AudioCodec.entries.firstOrNull { it.name == name } ?: return
        player.update { it.copy(codecPreference = codec) }
    }

    fun setLocalPlayerHiRes(enabled: Boolean) = player.update {
        it.copy(bitDepth = if (enabled) SettingsRepository.BIT_DEPTH_HI_RES else SettingsRepository.BIT_DEPTH_DEFAULT)
    }

    fun setLocalPlayerBuffer(seconds: Int) = player.update {
        it.copy(
            bufferSeconds = seconds.coerceIn(
                SettingsRepository.BUFFER_SECONDS_MIN,
                SettingsRepository.BUFFER_SECONDS_MAX,
            ),
        )
    }

    fun saveLocalPlayer() = player.save()

    fun resetLocalPlayer() = player.reset()

    fun confirmLocalPlayer() = player.confirm()

    fun dismissLocalPlayer() = player.dismiss()

    fun shareLogs(chooserTitle: String) = settings.shareLogs(chooserTitle)

    fun dismissLocalNetworkHint() = settings.dismissLocalNetworkOnboarding()

    fun removeHistory(historyKey: String) {
        settings.connectionHistory.value.firstOrNull { it.historyKey == historyKey }?.let(settings::removeFromHistory)
    }

    private suspend fun Parts.toState(): NativeSettingsState {
        val session = connection.session
        val connected = session as? SessionState.Connected
        val serverInfo = connected?.serverInfo
        val phase = when {
            connected?.dataConnectionState is DataConnectionState.Authenticated -> NativeSessionPhase.SIGNED_IN
            connected != null -> NativeSessionPhase.AWAITING_AUTH
            session is SessionState.Connecting || session is SessionState.Reconnecting -> NativeSessionPhase.CONNECTING
            else -> NativeSessionPhase.DISCONNECTED
        }
        val saved = connection.saved
        val error = (session as? SessionState.Disconnected.Error)?.reason
        val guidanceText = settings
            .localNetworkErrorGuidance(error, guidance.probeGranted, guidance.localNetworkBlocked)
            ?.let { getString(it) }
        val onboarding = settings.localNetworkOnboardingResources
            ?.takeIf { guidance.history.isEmpty() && !guidance.onboardingShown }
        return NativeSettingsState(
            phase = phase,
            usesWebRtc = connection.usesWebRtc,
            savedHost = saved?.host.orEmpty(),
            savedPort = (saved?.port ?: DEFAULT_PORT).toString(),
            savedTls = saved?.isTls == true,
            savedBasePath = saved?.basePath.orEmpty(),
            webrtcRemoteId = connection.remoteId,
            connectInFlight = connection.inFlight,
            connectingTo = when {
                phase != NativeSessionPhase.CONNECTING -> null
                connection.usesWebRtc -> null
                else -> saved?.let { "${it.host}:${it.port}" }
            },
            errorMessage = guidanceText ?: error?.message,
            serverName = serverInfo?.name?.takeIf { it.isNotBlank() },
            serverAddress = when (connected) {
                is SessionState.Connected.WebRTC -> REMOTE_ACCESS
                else -> saved?.let { "${it.host}:${it.port}${it.basePath}" }
            },
            serverVersion = serverInfo?.serverVersion,
            userDescription = connected?.user?.description,
            authProviders = account.providers.mapNotNull { it.toNative() },
            authBusy = account.authState is AuthState.Loading,
            authError = (account.authState as? AuthState.Error)?.message,
            themeName = account.theme.name,
            allowLandscape = account.landscape,
            localPlayer = localPlayer,
            history = guidance.history.map { it.toNative() },
            appVersion = "${settings.appVersion.name} (${settings.appVersion.code})",
            isPreparingShare = guidance.preparingShare,
            localNetworkTitle = onboarding?.let { getString(it.title) },
            localNetworkBody = onboarding?.let { getString(it.body) },
        )
    }

    private data class ConnectionPart(
        val session: SessionState,
        val saved: ConnectionInfo?,
        val usesWebRtc: Boolean,
        val remoteId: String,
        val inFlight: Boolean,
    )

    private data class GuidancePart(
        val localNetworkBlocked: Boolean,
        val probeGranted: Boolean?,
        val history: List<ConnectionHistoryEntry>,
        val onboardingShown: Boolean,
        val preparingShare: Boolean,
    )

    private data class AccountPart(
        val authState: AuthState,
        val providers: List<AuthProvider>,
        val theme: ThemeSetting,
        val landscape: Boolean,
    )

    private data class Parts(
        val connection: ConnectionPart,
        val guidance: GuidancePart,
        val account: AccountPart,
        val localPlayer: NativeLocalPlayer,
    )

    private companion object {
        const val DIRECT = "direct"
        const val WEBRTC = "webrtc"
        const val DEFAULT_HOST = "homeassistant.local"
        const val DEFAULT_PORT = 8095
        const val REMOTE_ACCESS = "Remote access (WebRTC)"

        val initialState = NativeSettingsState(
            phase = NativeSessionPhase.DISCONNECTED,
            usesWebRtc = false,
            savedHost = "",
            savedPort = DEFAULT_PORT.toString(),
            savedTls = false,
            savedBasePath = "",
            webrtcRemoteId = "",
            connectInFlight = false,
            connectingTo = null,
            errorMessage = null,
            serverName = null,
            serverAddress = null,
            serverVersion = null,
            userDescription = null,
            authProviders = emptyList(),
            authBusy = false,
            authError = null,
            themeName = ThemeSetting.FollowSystem.name,
            allowLandscape = false,
            localPlayer = NativeLocalPlayer(false, "", "", emptyList(), false, false, 0, false, false, false),
            history = emptyList(),
            appVersion = "",
            isPreparingShare = false,
            localNetworkTitle = null,
            localNetworkBody = null,
        )
    }
}

private fun AuthProvider.toNative(): NativeAuthProvider? = when (type) {
    "builtin" -> NativeAuthProvider(id, isBuiltin = true, isHomeAssistant = false)
    "homeassistant" -> NativeAuthProvider(id, isBuiltin = false, isHomeAssistant = true)
    else -> null
}

private fun ConnectionHistoryEntry.toNative(): NativeHistoryEntry {
    val webRtc = type == ConnectionType.WEBRTC
    val address = if (webRtc) remoteId.orEmpty() else "${host.orEmpty()}:${port ?: ""}$basePath"
    return NativeHistoryEntry(
        historyKey = historyKey,
        title = serverName?.takeIf { it.isNotBlank() } ?: address,
        subtitle = address,
        isWebRtc = webRtc,
        host = host,
        port = port,
        isTls = isTls == true,
        basePath = basePath,
        remoteId = remoteId,
    )
}

/**
 * The iOS settings host: holds how to leave the top-level settings screen for the main screen,
 * while that screen is composed. Swift calls [goHome] through `KmpHelper.settingsGoHome()`.
 */
object IosSettingsHost : NativeSettingsHost {
    private var goHomeAction: (() -> Unit)? = null
    private var owner: Any? = null
    private val mutableShowing = MutableStateFlow(false)

    /** True while the top-level settings screen is on, not the tabs. */
    val showing: StateFlow<Boolean> = mutableShowing.asStateFlow()

    @Composable
    override fun Publish(goHome: () -> Unit) {
        val token = remember { Any() }
        SideEffect {
            owner = token
            goHomeAction = goHome
            mutableShowing.value = true
        }
        DisposableEffect(token) {
            onDispose {
                if (owner === token) {
                    owner = null
                    goHomeAction = null
                    mutableShowing.value = false
                }
            }
        }
    }

    fun goHome() {
        goHomeAction?.invoke()
    }
}

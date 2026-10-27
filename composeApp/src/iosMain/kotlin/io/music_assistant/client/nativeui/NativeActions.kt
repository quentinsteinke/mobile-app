package io.music_assistant.client.nativeui

import io.music_assistant.client.data.MainDataSource
import io.music_assistant.client.data.model.client.ClickContext
import io.music_assistant.client.data.model.client.QueueOption
import io.music_assistant.client.data.model.client.items.Playlist
import io.music_assistant.client.data.model.client.items.PodcastEpisode
import io.music_assistant.client.ui.compose.common.items.ItemAction
import io.music_assistant.client.ui.compose.common.items.resolveLongClickActions
import io.music_assistant.client.ui.compose.common.items.supportsAddToPlaylist
import io.music_assistant.client.ui.compose.common.items.title
import io.music_assistant.client.ui.compose.common.items.toPlayMode
import io.music_assistant.client.ui.compose.common.viewmodel.ActionsViewModel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.getString
import org.koin.core.component.get

/** An entry of the long-press menu of a native row or tile. */
enum class NativeAction(internal val action: ItemAction) {
    PLAY_NOW(ItemAction.Play(QueueOption.REPLACE)),
    PLAY_NEXT_AND_PLAY(ItemAction.Play(QueueOption.PLAY)),
    PLAY_NEXT(ItemAction.Play(QueueOption.NEXT)),
    ADD_TO_QUEUE(ItemAction.Play(QueueOption.ADD)),
    REPLACE_NEXT(ItemAction.Play(QueueOption.REPLACE_NEXT)),
    PLAY_FROM_HERE(ItemAction.PlayFromHere),
    PLAY_SHUFFLED(ItemAction.PlayShuffled),
    PLAY_FROM_BEGINNING(ItemAction.PlayFromBeginning),
    START_RADIO(ItemAction.StartEndlessMix),
    ADD_TO_LIBRARY(ItemAction.AddToLibrary),
    REMOVE_FROM_LIBRARY(ItemAction.RemoveFromLibrary),
    FAVORITE(ItemAction.Favorite),
    UNFAVORITE(ItemAction.Unfavorite),
    DISLIKE(ItemAction.Dislike),
    REMOVE_DISLIKE(ItemAction.RemoveDislike),
    ADD_TO_PLAYLIST(ItemAction.AddToPlaylist),
    REMOVE_FROM_PLAYLIST(ItemAction.RemoveFromPlaylist),
    MARK_PLAYED(ItemAction.MarkPlayed),
    MARK_UNPLAYED(ItemAction.MarkUnplayed),
    ;

    /** A play entry; the others change the library. */
    val plays: Boolean get() = action.kind == ItemAction.Kind.PLAYBACK

    internal companion object {
        fun of(action: ItemAction): NativeAction? = entries.firstOrNull { it.action == action }
    }
}

/** Where a native list is, for the entries that depend on it ("Play album from here"). */
enum class NativeMenuContext(internal val context: ClickContext?) {
    LIST(null),
    ALBUM(ClickContext.ALBUM),
    PLAYLIST(ClickContext.PLAYLIST),
    PODCAST(ClickContext.PODCAST),
}

/**
 * The long-press menus of the native screens, with the same entries and gates as the Compose
 * menus ([resolveLongClickActions]), and the actions behind them, through [ActionsViewModel].
 * One for the app: the menus and the toasts outlive a screen.
 */
object NativeActions : NativeScreen() {
    private val actions = viewModel { get<ActionsViewModel>() }
    private val dataSource: MainDataSource = get()

    private val _titles = MutableStateFlow<Map<Pair<NativeAction, NativeMenuContext>, String>>(emptyMap())

    /** The menu titles in the app language, once loaded. */
    val titles: StateFlow<Map<Pair<NativeAction, NativeMenuContext>, String>> = _titles.asStateFlow()

    /** Messages for the user after an action, such as "Added to <playlist>". */
    val toasts: Flow<String> = actions.toasts

    init {
        scope.launch {
            _titles.value = buildMap {
                NativeAction.entries.forEach { action ->
                    NativeMenuContext.entries.forEach { context ->
                        put(action to context, getString(action.action.title(context.context)))
                    }
                }
            }
        }
    }

    /** The title of [action] in [context]. */
    fun title(action: NativeAction, context: NativeMenuContext): String =
        _titles.value[action to context] ?: action.name.lowercase().replace('_', ' ').replaceFirstChar { it.uppercase() }

    /**
     * The menu of [item] in [context], in the Compose order. [inEditablePlaylist] offers
     * "Remove from playlist" for a row of a playlist the user can edit.
     */
    fun menu(item: NativeMediaItem, context: NativeMenuContext, inEditablePlaylist: Boolean): List<NativeAction> =
        resolveLongClickActions(
            item = item.item,
            clickContext = context.context,
            canEditLibrary = dataSource.grantedScopes.value.canEditLibrary,
            dislikeSupported = dataSource.dislikeSupported.value,
            librarySupported = true,
            canAddToPlaylist = item.item.supportsAddToPlaylist,
            canRemoveFromPlaylist = inEditablePlaylist && item.position != null,
            progressSupported = item.item is PodcastEpisode,
            playMediaSupport = dataSource.playMediaSupport.value,
        ).mapNotNull { NativeAction.of(it) }

    /**
     * Runs [action] on [item]. Play from here and Remove from playlist need the page that lists
     * the item, so its native screen handles them, and they do nothing here.
     */
    fun perform(item: NativeMediaItem, action: NativeAction) {
        when (action) {
            NativeAction.PLAY_FROM_HERE, NativeAction.REMOVE_FROM_PLAYLIST, NativeAction.ADD_TO_PLAYLIST -> Unit
            NativeAction.ADD_TO_LIBRARY, NativeAction.REMOVE_FROM_LIBRARY -> actions.onLibraryClick(item.item)
            NativeAction.MARK_PLAYED -> actions.onMarkPlayed(item.item)
            NativeAction.MARK_UNPLAYED -> actions.onMarkUnplayed(item.item)
            else -> (action.action as? ItemAction.SetFavorite)
                ?.let { actions.onFavoriteChange(item.item, it.favorite) }
                ?: action.action.toPlayMode()?.let { actions.onPlayClick(item.item, it) }
        }
    }

    /** The playlists that the user can add [item] to. */
    suspend fun editablePlaylists(item: NativeMediaItem): List<NativeMediaItem> =
        actions.getEditablePlaylists().filter { it.accepts(item.item) }.map { it.toNative() }

    fun addToPlaylist(item: NativeMediaItem, playlist: NativeMediaItem) {
        (playlist.item as? Playlist)?.let { actions.addToPlaylist(item.item.uri, it) }
    }

    /** Creates a playlist named [name], or returns null if the server did not confirm it. */
    suspend fun createPlaylist(name: String): NativeMediaItem? = actions.createPlaylist(name)?.toNative()

    /** Removes the row at the server [position] from [playlistId], then runs [onDone]. */
    fun removeFromPlaylist(playlistId: String, position: Int, onDone: () -> Unit) =
        actions.removeFromPlaylist(playlistId, position, onDone)
}

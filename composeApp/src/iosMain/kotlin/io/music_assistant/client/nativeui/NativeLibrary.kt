package io.music_assistant.client.nativeui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.music_assistant.client.data.MainDataSource
import io.music_assistant.client.data.model.client.ImageType
import io.music_assistant.client.data.model.client.MediaType
import io.music_assistant.client.data.model.client.QueueOption
import io.music_assistant.client.data.model.client.SortOption
import io.music_assistant.client.data.model.client.items.Album
import io.music_assistant.client.data.model.client.items.AppMediaItem
import io.music_assistant.client.data.model.client.items.Artist
import io.music_assistant.client.data.model.client.items.Audiobook
import io.music_assistant.client.data.model.client.items.PlayableItem
import io.music_assistant.client.data.model.client.items.PodcastEpisode
import io.music_assistant.client.data.model.client.items.Track
import io.music_assistant.client.data.model.client.items.canBeFavorited
import io.music_assistant.client.data.model.client.items.image
import io.music_assistant.client.data.play.PlayMode
import io.music_assistant.client.ui.compose.common.DataState
import io.music_assistant.client.ui.compose.common.items.canPlayShuffled
import io.music_assistant.client.ui.compose.common.viewmodel.ActionsViewModel
import io.music_assistant.client.ui.compose.item.ItemDetailsViewModel
import io.music_assistant.client.ui.compose.item.artist.ArtistDetailsViewModel
import io.music_assistant.client.ui.compose.item.opensItemDetails
import io.music_assistant.client.ui.compose.library.LibraryCategoriesViewModel
import io.music_assistant.client.ui.compose.library.LibraryListViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import org.koin.core.component.KoinComponent
import org.koin.core.component.get
import org.koin.core.parameter.parametersOf

/**
 * A row or tile of a native list. [item] goes back to Kotlin unchanged, for playing and for
 * opening its details.
 */
data class NativeMediaItem(
    val key: String,
    val itemId: String,
    val provider: String,
    val mediaType: MediaType,
    val title: String,
    val subtitle: String?,
    val artworkUrl: String?,
    val durationSec: Double?,
    val trackNumber: Int?,
    val discNumber: Int?,
    val year: Int?,
    val isExplicit: Boolean,
    val favorite: Boolean?,
    val isInLibrary: Boolean,
    val isPlayable: Boolean,
    val opensDetails: Boolean,
    val canPlayShuffled: Boolean,
    val canBeFavorited: Boolean,
    val item: AppMediaItem,
)

/** Where a list or a detail page is in its first load. */
enum class NativeLoad { LOADING, LOADED, EMPTY, ERROR }

internal fun AppMediaItem.toNative(): NativeMediaItem = NativeMediaItem(
    key = "${mediaType.serverValue}/$provider/$itemId",
    itemId = itemId,
    provider = provider,
    mediaType = mediaType,
    title = displayName,
    subtitle = subtitle,
    artworkUrl = (this as? PlayableItem)?.image(ImageType.THUMB)?.url ?: image(ImageType.THUMB)?.url,
    durationSec = (this as? PlayableItem)?.duration,
    trackNumber = (this as? Track)?.trackNumber,
    discNumber = (this as? Track)?.discNumber,
    year = (this as? Album)?.year,
    isExplicit = isExplicit,
    favorite = favorite,
    isInLibrary = isInLibrary,
    isPlayable = isPlayable,
    opensDetails = opensItemDetails,
    canPlayShuffled = canPlayShuffled,
    canBeFavorited = canBeFavorited,
    item = this,
)

private fun <T> DataState<List<T>>.load(): NativeLoad = when (this) {
    is DataState.Loading -> NativeLoad.LOADING
    is DataState.Error -> NativeLoad.ERROR
    else -> if (dataOrNull.isNullOrEmpty()) NativeLoad.EMPTY else NativeLoad.LOADED
}

/**
 * Owns the view models of one native screen. [close] clears them, which cancels their
 * coroutines, as leaving a Compose navigation entry does.
 */
abstract class NativeScreen : KoinComponent {
    @PublishedApi internal val store = ViewModelStore()
    protected val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    protected inline fun <reified T : ViewModel> viewModel(crossinline create: () -> T): T =
        ViewModelProvider.create(store, viewModelFactory { initializer { create() } })[T::class]

    fun close() {
        scope.cancel()
        store.clear()
    }
}

/** A library category as the native Library screen shows it. */
data class NativeCategory(val name: String, val mediaType: MediaType?)

/** The visible library categories, in the user's order. */
class NativeLibraryCategories : NativeScreen() {
    private val categories = viewModel { get<LibraryCategoriesViewModel>() }

    val state: StateFlow<List<NativeCategory>> = categories.state
        .map { state ->
            state.categories.filter { it.enabled }.map {
                NativeCategory(it.libraryCategory.name, it.libraryCategory.mediaType)
            }
        }
        .stateIn(scope, SharingStarted.Eagerly, emptyList())
}

/** A sort field that a list offers. */
data class NativeSortChoice(val fieldName: String, val title: String, val supportsDirection: Boolean)

/** The state of a native library list. */
data class NativeListState(
    val load: NativeLoad,
    val items: List<NativeMediaItem>,
    val isLoadingMore: Boolean,
    val hasMore: Boolean,
    val searchQuery: String,
    val favoritesOnly: Boolean,
    val sortChoices: List<NativeSortChoice>,
    val sortFieldName: String,
    val sortDescending: Boolean,
)

/** One library list (albums, artists, tracks...), over [LibraryListViewModel]. */
class NativeLibraryList(mediaType: MediaType) : NativeScreen() {
    private val list = viewModel { get<LibraryListViewModel> { parametersOf(mediaType) } }
    private val dataSource: MainDataSource = get()

    val state: StateFlow<NativeListState> = list.state
        .map { state ->
            val menu = state.sortMenu
            NativeListState(
                load = state.dataState.load(),
                items = state.dataState.dataOrNull.orEmpty().map { it.toNative() },
                isLoadingMore = state.isLoadingMore,
                hasMore = state.hasMore,
                searchQuery = state.searchQuery,
                favoritesOnly = state.filters.favorite,
                sortChoices = menu?.offers.orEmpty().map {
                    NativeSortChoice(it.field.name, it.field.displayName, it.supportsDirection)
                },
                sortFieldName = state.sortOption.field.name,
                sortDescending = state.sortOption.descending,
            )
        }
        .stateIn(scope, SharingStarted.Eagerly, initialState)

    /** Shuffle play is offered for this server and these items. */
    val canShuffle: Boolean get() = dataSource.playMediaSupport.value.shuffle

    fun loadMore() = list.loadMore()

    fun search(query: String) {
        list.onSearchQueryChanged(query)
        list.onSearch()
    }

    fun setFavoritesOnly(enabled: Boolean) {
        list.setFilters(list.state.value.filters.copy(favorite = enabled))
    }

    /** Picks [fieldName]; picking the current field again flips the direction. */
    fun sort(fieldName: String) {
        val current = list.state.value.sortOption
        val offer = list.state.value.sortMenu?.offers?.firstOrNull { it.field.name == fieldName } ?: return
        val option = if (current.field == offer.field && offer.supportsDirection) {
            current.copy(descending = !current.descending)
        } else {
            SortOption(offer.field, descending = offer.defaultDescending)
        }
        list.onSortChanged(option)
    }

    fun play(item: NativeMediaItem, shuffle: Boolean) =
        list.onPlayClick(item.item, PlayMode(QueueOption.REPLACE, shuffle = shuffle && canShuffle))

    private companion object {
        val initialState = NativeListState(
            load = NativeLoad.LOADING,
            items = emptyList(),
            isLoadingMore = false,
            hasMore = false,
            searchQuery = "",
            favoritesOnly = false,
            sortChoices = emptyList(),
            sortFieldName = "",
            sortDescending = false,
        )
    }
}

/** The state of a native detail page. The artist sections are empty for other items. */
data class NativeDetailsState(
    val load: NativeLoad,
    val header: NativeMediaItem?,
    val itemsLoad: NativeLoad,
    val items: List<NativeMediaItem>,
    val libraryAlbums: List<NativeMediaItem>,
    val allAlbums: List<NativeMediaItem>,
    val topTracks: List<NativeMediaItem>,
    val canEditLibrary: Boolean,
    val canShuffle: Boolean,
)

/**
 * One detail page (album, playlist, artist, podcast, audiobook, genre), over
 * [ItemDetailsViewModel], and [ArtistDetailsViewModel] for an artist.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class NativeItemDetails(itemId: String, mediaType: MediaType, provider: String) : NativeScreen() {
    private val details = viewModel { get<ItemDetailsViewModel> { parametersOf(itemId, mediaType, provider) } }
    private val actions = viewModel { get<ActionsViewModel>() }
    private val dataSource: MainDataSource = get()
    private var artistDetails: ArtistDetailsViewModel? = null

    /** The artist sections once the item loads as an artist; empty for every other item. */
    private val artistSections = details.state
        .map { it.itemState.dataOrNull as? Artist }
        .distinctUntilChanged { old, new -> old?.itemId == new?.itemId }
        .flatMapLatest { artist ->
            if (artist == null) return@flatMapLatest flowOf(ArtistSections())
            val artistViewModel = artistDetails ?: viewModel {
                get<ArtistDetailsViewModel> { parametersOf(artist) }
            }.also { artistDetails = it }
            combine(artistViewModel.library, artistViewModel.all, artistViewModel.topTracks) { library, all, top ->
                ArtistSections(
                    library = library.dataOrNull?.items.orEmpty().map { it.toNative() },
                    all = all.dataOrNull?.items.orEmpty().map { it.toNative() },
                    topTracks = top.dataOrNull?.items.orEmpty().map { it.toNative() },
                )
            }
        }

    val state: StateFlow<NativeDetailsState> = combine(
        details.state,
        artistSections,
        dataSource.grantedScopes,
        dataSource.playMediaSupport,
    ) { state, sections, scopes, support ->
        val header = state.itemState.dataOrNull
        NativeDetailsState(
            load = when (state.itemState) {
                is DataState.Loading -> NativeLoad.LOADING
                is DataState.Error -> NativeLoad.ERROR
                else -> if (header == null) NativeLoad.EMPTY else NativeLoad.LOADED
            },
            header = header?.toNative(),
            itemsLoad = state.playableItemsState.load(),
            items = state.playableItemsState.dataOrNull.orEmpty().mapNotNull { (it as? AppMediaItem)?.toNative() } +
                state.albumsState.dataOrNull.orEmpty().takeIf { header !is Artist }.orEmpty().map { it.toNative() },
            libraryAlbums = sections.library,
            allAlbums = sections.all,
            topTracks = sections.topTracks,
            canEditLibrary = scopes.canEditLibrary,
            canShuffle = support.shuffle && header?.canPlayShuffled == true,
        )
    }.stateIn(scope, SharingStarted.Eagerly, initialState)

    /** Plays the page's item, from the start or shuffled. */
    fun play(shuffle: Boolean) =
        details.onPlayClick(PlayMode(QueueOption.REPLACE, shuffle = shuffle && state.value.canShuffle))

    /**
     * Plays [item] from this page. A track of an album or playlist plays the container from that
     * track, as in Apple Music; other items play on their own.
     */
    fun play(item: NativeMediaItem) {
        val inContainer = item.item is Track || item.item is PodcastEpisode || item.item is Audiobook
        details.onPlayClick(item.item, PlayMode(QueueOption.REPLACE, fromHereInParent = inContainer))
    }

    /** Like the page's item, or take the like back. */
    fun toggleFavorite() {
        val item = details.state.value.itemState.dataOrNull ?: return
        actions.onFavoriteChange(item, if (item.favorite == true) null else true)
    }

    fun toggleFavorite(item: NativeMediaItem) =
        actions.onFavoriteChange(item.item, if (item.favorite == true) null else true)

    /** Adds the page's item to the library, or removes it. */
    fun toggleLibrary() {
        details.state.value.itemState.dataOrNull?.let { actions.onLibraryClick(it) }
    }

    fun reload() = details.reload()

    private data class ArtistSections(
        val library: List<NativeMediaItem> = emptyList(),
        val all: List<NativeMediaItem> = emptyList(),
        val topTracks: List<NativeMediaItem> = emptyList(),
    )

    private companion object {
        val initialState = NativeDetailsState(
            load = NativeLoad.LOADING,
            header = null,
            itemsLoad = NativeLoad.LOADING,
            items = emptyList(),
            libraryAlbums = emptyList(),
            allAlbums = emptyList(),
            topTracks = emptyList(),
            canEditLibrary = false,
            canShuffle = false,
        )
    }
}

package io.music_assistant.client.nativeui

import io.music_assistant.client.data.MainDataSource
import io.music_assistant.client.data.model.client.MediaType
import io.music_assistant.client.data.model.client.QueueOption
import io.music_assistant.client.data.play.PlayMode
import io.music_assistant.client.ui.compose.common.DataState
import io.music_assistant.client.ui.compose.home.HomeScreenViewModel
import io.music_assistant.client.ui.compose.home.getCategories
import io.music_assistant.client.ui.compose.search.SearchViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.mapLatest
import kotlinx.coroutines.flow.stateIn
import musicassistantclient.composeapp.generated.resources.Res
import musicassistantclient.composeapp.generated.resources.home_shortcuts
import org.jetbrains.compose.resources.getString
import org.koin.core.component.get

/** A row of the native home page. [title] is localized. */
data class NativeHomeRow(
    val rowId: String,
    val title: String,
    val items: List<NativeMediaItem>,
    val isLoading: Boolean,
)

data class NativeHomeState(val load: NativeLoad, val rows: List<NativeHomeRow>)

/**
 * The native home page over [HomeScreenViewModel]. The rows, their order and the hidden rows
 * come from the same rules as the Compose home page (`getCategories`, the home row settings).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class NativeHome : NativeScreen() {
    private val home = viewModel { get<HomeScreenViewModel>() }
    private val dataSource: MainDataSource = get()

    val state: StateFlow<NativeHomeState> = home.state
        .mapLatest { state ->
            val shortcutsTitle = getString(Res.string.home_shortcuts)
            val folderNames = state.recommendations.dataOrNull.orEmpty()
                .associate { it.folder.itemId to it.folder.displayName }
            val rows = getCategories(state.recommendations, state.shortcuts, state.homeRowsConfig)
                .filter { (_, enabled) -> enabled }
                .map { (row, _) ->
                    NativeHomeRow(
                        rowId = row.category.id,
                        title = folderNames[row.category.id] ?: shortcutsTitle,
                        items = row.category.items.map { it.toNative() },
                        isLoading = row.loading,
                    )
                }
            NativeHomeState(
                load = when (state.recommendations) {
                    is DataState.Loading -> NativeLoad.LOADING
                    is DataState.Error -> NativeLoad.ERROR
                    else -> if (rows.isEmpty()) NativeLoad.EMPTY else NativeLoad.LOADED
                },
                rows = rows,
            )
        }
        .stateIn(scope, SharingStarted.Eagerly, NativeHomeState(NativeLoad.LOADING, emptyList()))

    val canShuffle: Boolean get() = dataSource.playMediaSupport.value.shuffle

    fun refresh() = home.loadData()

    fun play(item: NativeMediaItem, shuffle: Boolean) =
        home.onPlayClick(item.item, PlayMode(QueueOption.REPLACE, shuffle = shuffle && canShuffle))
}

/** A section of search results ("Songs", "Artists"...). [title] is localized. */
data class NativeSearchSection(val title: String, val mediaType: MediaType, val items: List<NativeMediaItem>)

data class NativeSearchState(
    val query: String,
    val load: NativeLoad,
    val sections: List<NativeSearchSection>,
    val libraryOnly: Boolean,
)

/** The native search over [SearchViewModel]. An empty query gives no sections. */
@OptIn(ExperimentalCoroutinesApi::class)
class NativeSearch : NativeScreen() {
    private val search = viewModel { get<SearchViewModel>() }
    private val dataSource: MainDataSource = get()

    val state: StateFlow<NativeSearchState> = search.state
        .mapLatest { state ->
            val results = state.resultsState.dataOrNull
            NativeSearchState(
                query = state.searchState.query,
                load = when (state.resultsState) {
                    is DataState.Loading -> NativeLoad.LOADING
                    is DataState.Error -> NativeLoad.ERROR
                    is DataState.NoData -> NativeLoad.EMPTY
                    else -> if (results?.nonEmptyLists.isNullOrEmpty()) NativeLoad.EMPTY else NativeLoad.LOADED
                },
                sections = results?.nonEmptyLists.orEmpty().map { section ->
                    NativeSearchSection(
                        title = getString(section.mediaTypeName),
                        mediaType = section.items.first().mediaType,
                        items = section.items.map { it.toNative() },
                    )
                },
                libraryOnly = state.searchState.libraryOnly,
            )
        }
        .stateIn(scope, SharingStarted.Eagerly, NativeSearchState("", NativeLoad.EMPTY, emptyList(), false))

    val canShuffle: Boolean get() = dataSource.playMediaSupport.value.shuffle

    fun search(query: String) {
        search.onQueryChanged(query)
        search.onSearch()
    }

    fun setLibraryOnly(enabled: Boolean) =
        search.onFiltersChanged(search.state.value.searchState.selectedMediaTypes, enabled)

    fun play(item: NativeMediaItem, shuffle: Boolean) =
        search.onPlayClick(item.item, PlayMode(QueueOption.REPLACE, shuffle = shuffle && canShuffle))
}

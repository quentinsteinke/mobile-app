import SwiftUI
import ComposeApp

// SwiftUI models over the Kotlin screens of NativeLibrary.kt. Each one follows its Kotlin state
// flow while the view exists, and closes the Kotlin screen (and its view models) when it goes.

@MainActor
final class LibraryCategoriesModel: ObservableObject {
    @Published private(set) var categories: [NativeCategory]
    private let screen = NativeLibraryCategories()
    private var task: Task<Void, Never>?

    init() {
        categories = screen.state.value
        task = Task { [weak self, screen] in
            for await value in screen.state { self?.categories = value }
        }
    }

    deinit {
        task?.cancel()
        screen.close()
    }
}

@MainActor
final class LibraryListModel: ObservableObject {
    @Published private(set) var state: NativeListState
    let screen: NativeLibraryList
    private var task: Task<Void, Never>?

    init(mediaType: MediaType) {
        screen = NativeLibraryList(mediaType: mediaType)
        state = screen.state.value
        task = Task { [weak self, screen] in
            for await value in screen.state { self?.state = value }
        }
    }

    deinit {
        task?.cancel()
        screen.close()
    }

    /// Asks for the next page when one of the last rows appears.
    func rowAppeared(_ item: NativeMediaItem) {
        guard state.hasMore, !state.isLoadingMore else { return }
        let items = state.items
        guard let index = items.firstIndex(where: { $0.key == item.key }), index >= items.count - 10 else { return }
        screen.loadMore()
    }
}

@MainActor
final class ItemDetailsModel: ObservableObject {
    @Published private(set) var state: NativeDetailsState
    let screen: NativeItemDetails
    private var task: Task<Void, Never>?

    init(route: LibraryRoute) {
        screen = NativeItemDetails(itemId: route.itemId, mediaType: route.mediaType, provider: route.provider)
        state = screen.state.value
        task = Task { [weak self, screen] in
            for await value in screen.state { self?.state = value }
        }
    }

    deinit {
        task?.cancel()
        screen.close()
    }
}

/// A navigation destination of the native library.
enum LibraryRoute: Hashable {
    case list(MediaType)
    case item(itemId: String, mediaType: MediaType, provider: String, title: String)

    static func item(_ item: NativeMediaItem) -> LibraryRoute {
        .item(itemId: item.itemId, mediaType: item.mediaType, provider: item.provider, title: item.title)
    }

    var itemId: String {
        if case .item(let id, _, _, _) = self { return id }
        return ""
    }

    var mediaType: MediaType {
        switch self {
        case .list(let type): return type
        case .item(_, let type, _, _): return type
        }
    }

    var provider: String {
        if case .item(_, _, let provider, _) = self { return provider }
        return ""
    }
}

/// Titles and SF Symbols of the library categories. English for now, like `NativeStrings`.
extension MediaType {
    /// The menu context of the rows of a page of this type ("Play album from here").
    var menuContext: NativeMenuContext {
        switch self {
        case .album: .album
        case .playlist: .playlist
        case .podcast: .podcast
        default: .list
        }
    }

    var libraryTitle: String {
        switch self {
        case .artist: return "Artists"
        case .album: return "Albums"
        case .track: return "Songs"
        case .playlist: return "Playlists"
        case .audiobook: return "Audiobooks"
        case .podcast: return "Podcasts"
        case .radio: return "Radio"
        case .genre: return "Genres"
        default: return "Library"
        }
    }

    var librarySymbol: String {
        switch self {
        case .artist: return "music.microphone"
        case .album: return "square.stack"
        case .track: return "music.note"
        case .playlist: return "music.note.list"
        case .audiobook: return "books.vertical"
        case .podcast: return "antenna.radiowaves.left.and.right"
        case .radio: return "dot.radiowaves.left.and.right"
        case .genre: return "guitars"
        default: return "square.grid.2x2"
        }
    }

    /// Lists of these types show tiles; the others show rows.
    var showsGrid: Bool {
        switch self {
        case .album, .playlist, .podcast, .audiobook, .radio: return true
        default: return false
        }
    }
}

extension NativeMediaItem {
    var duration: Double? { durationSec?.doubleValue }
    var isFavorite: Bool { favorite?.boolValue == true }
}

/// "3:45" for a row, or "1 hr 12 min" for a total.
func formatTotalDuration(_ seconds: Double) -> String {
    let minutes = Int((seconds / 60).rounded())
    if minutes < 60 { return "\(minutes) min" }
    return "\(minutes / 60) hr \(minutes % 60) min"
}

@MainActor
final class HomeModel: ObservableObject {
    @Published private(set) var state: NativeHomeState
    let screen = NativeHome()
    private var task: Task<Void, Never>?

    init() {
        state = screen.state.value
        task = Task { [weak self, screen] in
            for await value in screen.state { self?.state = value }
        }
    }

    deinit {
        task?.cancel()
        screen.close()
    }
}

@MainActor
final class SearchModel: ObservableObject {
    @Published private(set) var state: NativeSearchState
    let screen = NativeSearch()
    private var task: Task<Void, Never>?

    init() {
        state = screen.state.value
        task = Task { [weak self, screen] in
            for await value in screen.state { self?.state = value }
        }
    }

    deinit {
        task?.cancel()
        screen.close()
    }
}

extension View {
    /// The detail pages that every native tab pushes: library lists and item pages.
    func nativeDestinations(bottomInset: CGFloat) -> some View {
        navigationDestination(for: LibraryRoute.self) { route in
            switch route {
            case .list(let mediaType):
                LibraryListView(mediaType: mediaType, bottomInset: bottomInset)
            case .item:
                ItemDetailView(route: route, bottomInset: bottomInset)
            }
        }
    }
}

import SwiftUI
import ComposeApp

/// The native Library tab: the categories, then a list per category and the detail pages. A wide
/// window (the unfolded iPhone Duo) keeps the categories in a sidebar beside the open category,
/// and in book posture the sidebar ends at the fold.
struct LibraryView: View {
    /// Room at the bottom for the mini player, which floats over the tab.
    var bottomInset: CGFloat = 0

    @StateObject private var model = LibraryCategoriesModel()
    @State private var path: [LibraryRoute] = []
    @State private var selected: MediaType?
    @State private var fold: FoldDivision?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            splitView
        } else {
            NavigationStack(path: $path) {
                List(model.categories, id: \.name) { category in
                    if let mediaType = category.mediaType {
                        NavigationLink(value: LibraryRoute.list(mediaType)) { CategoryLabel(mediaType: mediaType) }
                            .mediaRowInsets()
                            .listSectionSeparator(.hidden, edges: .top)
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Library")
                .nativeDestinations(bottomInset: bottomInset)
                .safeAreaPadding(.bottom, bottomInset)
            }
        }
    }

    private var splitView: some View {
        GeometryReader { geometry in
            NavigationSplitView(columnVisibility: .constant(.all)) {
                List(model.categories, id: \.name, selection: $selected) { category in
                    if let mediaType = category.mediaType {
                        CategoryLabel(mediaType: mediaType).tag(mediaType)
                    }
                }
                .navigationTitle("Library")
                .navigationSplitViewColumnWidth(sidebarWidth(geometry.size))
                .toolbar(removing: .sidebarToggle)
                .safeAreaPadding(.bottom, bottomInset)
            } detail: {
                NavigationStack(path: $path) {
                    Group {
                        if let selected {
                            LibraryListView(mediaType: selected, bottomInset: bottomInset)
                                .id(selected)
                        } else {
                            ContentUnavailableView("Library", systemImage: "square.stack")
                        }
                    }
                    .nativeDestinations(bottomInset: bottomInset)
                }
                // The open category starts past the fold.
                .safeAreaPadding(.leading, bookFold(geometry.size).map { $0.frame.width + foldGutter } ?? 0)
            }
            .navigationSplitViewStyle(.balanced)
        }
        .readsFold(into: $fold)
        .onChange(of: selected) { _, _ in path = [] }
        .onAppear { if selected == nil { selected = model.categories.compactMap(\.mediaType).first } }
        .onChange(of: model.categories.count) { _, _ in
            if selected == nil { selected = model.categories.compactMap(\.mediaType).first }
        }
    }

    private func bookFold(_ size: CGSize) -> FoldDivision? {
        fold.flatMap { $0.posture == .book && $0.splits(size) ? $0 : nil }
    }

    /// The sidebar ends where the fold starts in book posture.
    private func sidebarWidth(_ size: CGSize) -> CGFloat {
        bookFold(size)?.frame.minX ?? 280
    }
}

private struct CategoryLabel: View {
    let mediaType: MediaType

    var body: some View {
        Label {
            Text(mediaType.libraryTitle)
                .font(.title3)
        } icon: {
            Image(systemName: mediaType.librarySymbol)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 6)
    }
}

/// One library category: a grid of tiles or a list of rows, searchable, sortable and paged.
struct LibraryListView: View {
    let mediaType: MediaType
    var bottomInset: CGFloat = 0

    @StateObject private var model: LibraryListModel
    @State private var query = ""

    init(mediaType: MediaType, bottomInset: CGFloat) {
        self.mediaType = mediaType
        self.bottomInset = bottomInset
        _model = StateObject(wrappedValue: LibraryListModel(mediaType: mediaType))
    }

    var body: some View {
        content
            .navigationTitle(mediaType.libraryTitle)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search \(mediaType.libraryTitle)")
            .onChange(of: query) { _, newQuery in model.screen.search(query: newQuery) }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { sortMenu } }
            .safeAreaPadding(.bottom, bottomInset)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state.load {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            ContentUnavailableView(
                "Couldn't Load \(mediaType.libraryTitle)",
                systemImage: "exclamationmark.triangle",
                description: Text("Check the connection to your server.")
            )
        case .empty:
            if model.state.searchQuery.isEmpty {
                ContentUnavailableView(
                    "No \(mediaType.libraryTitle)",
                    systemImage: mediaType.librarySymbol,
                    description: Text(model.state.favoritesOnly ? "No favorites yet." : "Your library has none yet.")
                )
            } else {
                ContentUnavailableView.search(text: model.state.searchQuery)
            }
        default:
            if mediaType.showsGrid { grid } else { rows }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 16)], spacing: 20) {
                ForEach(model.state.items, id: \.key) { item in
                    itemLink(item) { MediaTile(item: item) }
                        .onAppear { model.rowAppeared(item) }
                }
            }
            .padding(.horizontal, pageMargin)
            .padding(.top, 8)
            pagingFooter
        }
    }

    private var rows: some View {
        List {
            ForEach(model.state.items, id: \.key) { item in
                itemLink(item) { MediaRow(item: item) }
                    .mediaRowInsets()
                    .listSectionSeparator(.hidden, edges: .top)
                    .onAppear { model.rowAppeared(item) }
            }
            pagingFooter
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var pagingFooter: some View {
        if model.state.isLoadingMore {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    /// Items with a detail page open it; the others (tracks, radio) play on tap.
    @ViewBuilder
    private func itemLink<Label: View>(_ item: NativeMediaItem, @ViewBuilder label: () -> Label) -> some View {
        let menu = MediaContextMenu(item: item, canShuffle: model.screen.canShuffle) { shuffle in
            model.screen.play(item: item, shuffle: shuffle)
        }
        if item.opensDetails {
            NavigationLink(value: LibraryRoute.item(item)) { label() }
                .buttonStyle(.plain)
                .contextMenu { menu }
        } else {
            Button { model.screen.play(item: item, shuffle: false) } label: { label() }
                .buttonStyle(.plain)
                .disabled(!item.isPlayable)
                .contextMenu { menu }
        }
    }

    private var sortMenu: some View {
        Menu {
            if !model.state.sortChoices.isEmpty {
                Section("Sort By") {
                    ForEach(model.state.sortChoices, id: \.fieldName) { choice in
                        Button {
                            model.screen.sort(fieldName: choice.fieldName)
                        } label: {
                            if choice.fieldName == model.state.sortFieldName {
                                Label(
                                    choice.title,
                                    systemImage: choice.supportsDirection
                                        ? (model.state.sortDescending ? "chevron.down" : "chevron.up")
                                        : "checkmark"
                                )
                            } else {
                                Text(choice.title)
                            }
                        }
                    }
                }
            }
            Section {
                Toggle(isOn: Binding(
                    get: { model.state.favoritesOnly },
                    set: { model.screen.setFavoritesOnly(enabled: $0) }
                )) {
                    Label("Favorites Only", systemImage: "heart")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Sort and Filter")
    }
}

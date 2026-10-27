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
    @State private var selected: LibraryRoute?
    @State private var fold: FoldDivision?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var editsCategories = false

    /// The route of each visible category, in the user's order.
    private var routes: [LibraryRoute] {
        model.categories.compactMap { category in
            if let mediaType = category.mediaType { return .list(mediaType) }
            switch category.name {
            case "BROWSE": return .browse(path: nil, title: "Browse")
            case "AI_RADIO": return .aiRadio
            default: return nil
            }
        }
    }

    var body: some View {
        Group {
            if sizeClass == .regular { splitView } else { stackView }
        }
        .sheet(isPresented: $editsCategories) {
            CategoriesEditor(choices: model.choices) { model.screen.save(choices: $0) }
        }
    }

    private var stackView: some View {
        Group {
            NavigationStack(path: $path) {
                List(routes, id: \.self) { route in
                    NavigationLink(value: route) { CategoryLabel(route: route) }
                        .mediaRowInsets()
                        .listSectionSeparator(.hidden, edges: .top)
                }
                .listStyle(.plain)
                .navigationTitle("Library")
                .toolbar { editButton }
                .nativeDestinations(bottomInset: bottomInset)
                .safeAreaPadding(.bottom, bottomInset)
            }
        }
    }

    private var splitView: some View {
        GeometryReader { geometry in
            NavigationSplitView(columnVisibility: .constant(.all)) {
                List(routes, id: \.self, selection: $selected) { route in
                    CategoryLabel(route: route).tag(route)
                }
                .navigationTitle("Library")
                .toolbar { editButton }
                .navigationSplitViewColumnWidth(sidebarWidth(geometry.size))
                .toolbar(removing: .sidebarToggle)
                .safeAreaPadding(.bottom, bottomInset)
            } detail: {
                NavigationStack(path: $path) {
                    Group {
                        switch selected {
                        case .list(let mediaType):
                            LibraryListView(mediaType: mediaType, bottomInset: bottomInset).id(mediaType)
                        case .browse(let browsePath, let title):
                            BrowseView(path: browsePath, title: title, bottomInset: bottomInset)
                        case .aiRadio:
                            AiRadioView(bottomInset: bottomInset)
                        default:
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
        .onAppear { if selected == nil { selected = routes.first } }
        .onChange(of: model.categories.count) { _, _ in
            if selected == nil { selected = routes.first }
        }
    }

    private var editButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Edit", systemImage: "slider.horizontal.3") { editsCategories = true }
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
    let route: LibraryRoute

    var body: some View {
        Label {
            Text(title)
                .font(.title3)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 6)
    }

    private var title: String {
        switch route {
        case .list(let mediaType): mediaType.libraryTitle
        case .browse: "Browse"
        case .aiRadio: "AI Radio"
        default: ""
        }
    }

    private var symbol: String {
        switch route {
        case .list(let mediaType): mediaType.librarySymbol
        case .browse: "folder"
        case .aiRadio: "sparkles"
        default: "square.stack"
        }
    }
}

/// One library category: a grid of tiles or a list of rows, searchable, sortable and paged.
struct LibraryListView: View {
    let mediaType: MediaType
    var bottomInset: CGFloat = 0

    @StateObject private var model: LibraryListModel
    @State private var query = ""
    @State private var asksPlaylistName = false
    @State private var newPlaylistName = ""

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
            .toolbar {
                if model.state.canCreatePlaylist {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New Playlist", systemImage: "plus") { asksPlaylistName = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
            }
            .alert("New Playlist", isPresented: $asksPlaylistName) {
                TextField("Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) { newPlaylistName = "" }
                Button("Create") {
                    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                    newPlaylistName = ""
                    if !name.isEmpty { model.screen.createPlaylist(name: name) }
                }
            }
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
            if model.state.showsGrid { grid } else { rows }
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
        let menu = MediaContextMenu(item: item)
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
                if mediaType == .audiobook {
                    Toggle(isOn: Binding(
                        get: { model.state.groupsSeries },
                        set: { _ in model.screen.toggleSeriesGrouping() }
                    )) {
                        Label("Group Series", systemImage: "books.vertical")
                    }
                }
            }
            Section {
                Button {
                    model.screen.toggleViewMode()
                } label: {
                    Label(model.state.showsGrid ? "View as List" : "View as Grid",
                          systemImage: model.state.showsGrid ? "list.bullet" : "square.grid.2x2")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Sort and Filter")
    }
}

/// Orders the library categories and shows or hides each one.
private struct CategoriesEditor: View {
    @State var choices: [NativeCategoryChoice]
    let save: ([NativeCategoryChoice]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(choices.enumerated()), id: \.element.name) { index, choice in
                    Toggle(isOn: Binding(
                        get: { choices[index].enabled },
                        set: { choices[index] = NativeCategoryChoice(name: choice.name, mediaType: choice.mediaType, enabled: $0) }
                    )) {
                        Label(title(choice), systemImage: symbol(choice))
                    }
                }
                .onMove { choices.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Library Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(choices)
                        dismiss()
                    }
                }
            }
        }
    }

    private func title(_ choice: NativeCategoryChoice) -> String {
        if let mediaType = choice.mediaType { return mediaType.libraryTitle }
        switch choice.name {
        case "BROWSE": return "Browse"
        case "AI_RADIO": return "AI Radio"
        default: return choice.name.capitalized
        }
    }

    private func symbol(_ choice: NativeCategoryChoice) -> String {
        if let mediaType = choice.mediaType { return mediaType.librarySymbol }
        return choice.name == "AI_RADIO" ? "sparkles" : "folder"
    }
}

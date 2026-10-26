import SwiftUI
import ComposeApp

/// The native Search tab: one field, results grouped by type.
struct SearchView: View {
    var bottomInset: CGFloat = 0

    @StateObject private var model = SearchModel()
    @State private var query = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Artists, Songs, Albums and More"
                )
                .onChange(of: query) { _, newQuery in model.screen.search(query: newQuery) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Toggle(isOn: Binding(
                                get: { model.state.libraryOnly },
                                set: { model.screen.setLibraryOnly(enabled: $0) }
                            )) {
                                Label("Library Only", systemImage: "square.stack")
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                        .accessibilityLabel("Filter")
                    }
                }
                .nativeDestinations(bottomInset: bottomInset)
                .safeAreaPadding(.bottom, bottomInset)
        }
    }

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView(
                "Search Your Music",
                systemImage: "magnifyingglass",
                description: Text("Find artists, albums, songs, playlists, podcasts and more.")
            )
        } else {
            switch model.state.load {
            case .loading where model.state.sections.isEmpty:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error:
                ContentUnavailableView(
                    "Couldn't Search",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Check the connection to your server.")
                )
            case .empty:
                ContentUnavailableView.search(text: query)
            default:
                List {
                    ForEach(model.state.sections, id: \.title) { section in
                        Section {
                            ForEach(section.items, id: \.key) { item in
                                row(item)
                                    .mediaRowInsets()
                            }
                        } header: {
                            Text(section.title)
                                .textCase(nil)
                        }
                        .headerProminence(.increased)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func row(_ item: NativeMediaItem) -> some View {
        let menu = MediaContextMenu(item: item, canShuffle: model.screen.canShuffle) { shuffle in
            model.screen.play(item: item, shuffle: shuffle)
        }
        if item.opensDetails && item.mediaType != .track {
            NavigationLink(value: LibraryRoute.item(item)) { MediaRow(item: item) }
                .contextMenu { menu }
        } else {
            Button { model.screen.play(item: item, shuffle: false) } label: { MediaRow(item: item) }
                .buttonStyle(.plain)
                .disabled(!item.isPlayable)
                .contextMenu { menu }
        }
    }
}

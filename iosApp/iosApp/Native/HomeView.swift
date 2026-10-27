import SwiftUI
import ComposeApp

/// The native Home tab: the server's recommendation rows, as horizontally scrolling tiles.
struct HomeView: View {
    var bottomInset: CGFloat = 0

    @StateObject private var model = HomeModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Home")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Refresh", systemImage: "arrow.clockwise") { model.screen.refresh() }
                    }
                }
                .nativeDestinations(bottomInset: bottomInset)
                .safeAreaPadding(.bottom, bottomInset)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state.load {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            ContentUnavailableView {
                Label("Couldn't Load Home", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Check the connection to your server.")
            } actions: {
                Button("Try Again") { model.screen.refresh() }
            }
        case .empty:
            ContentUnavailableView(
                "Nothing Here Yet",
                systemImage: "music.note.house",
                description: Text("Play something, and your recent music shows up here.")
            )
        default:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(model.state.rows, id: \.rowId) { row in
                        HomeRowView(row: row, model: model)
                    }
                }
                .padding(.vertical, 12)
            }
            .refreshable { model.screen.refresh() }
        }
    }
}

private struct HomeRowView: View {
    let row: NativeHomeRow
    @ObservedObject var model: HomeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(row.title)
                .font(.title2.weight(.bold))
                .padding(.horizontal, pageMargin)
            if row.isLoading && row.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(row.items, id: \.key) { item in
                            tile(item)
                        }
                    }
                    .padding(.horizontal, pageMargin)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    @ViewBuilder
    private func tile(_ item: NativeMediaItem) -> some View {
        let menu = MediaContextMenu(item: item)
        Group {
            if item.opensDetails {
                NavigationLink(value: LibraryRoute.item(item)) { MediaTile(item: item) }
            } else {
                Button { model.screen.play(item: item, shuffle: false) } label: { MediaTile(item: item) }
                    .disabled(!item.isPlayable)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 150)
        .scrollTargetLayout()
        .contextMenu { menu }
    }
}

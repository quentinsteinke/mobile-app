import SwiftUI
import ComposeApp

/// The native detail page of an album, playlist, podcast, audiobook, genre or artist. A wide
/// window (the unfolded iPhone Duo) puts the header beside the list.
struct ItemDetailView: View {
    let route: LibraryRoute
    var bottomInset: CGFloat = 0

    @StateObject private var model: ItemDetailsModel
    @State private var fold: FoldDivision?

    init(route: LibraryRoute, bottomInset: CGFloat) {
        self.route = route
        self.bottomInset = bottomInset
        _model = StateObject(wrappedValue: ItemDetailsModel(route: route))
    }

    private var title: String {
        if case .item(_, _, _, let title) = route { return title }
        return ""
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                switch model.state.load {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .error, .empty:
                    ContentUnavailableView(
                        "Couldn't Load \(title)",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Check the connection to your server.")
                    )
                default:
                    if let header = model.state.header {
                        if header.mediaType == .artist {
                            ArtistPage(model: model, header: header)
                        } else if fold?.splits(geometry.size) == true || geometry.size.width > 760 {
                            splitPage(header)
                        } else {
                            tallPage(header)
                        }
                    }
                }
            }
        }
        .readsFold(into: $fold)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { overflowMenu } }
        .safeAreaPadding(.bottom, bottomInset)
    }

    private func tallPage(_ header: NativeMediaItem) -> some View {
        List {
            DetailHeader(model: model, header: header)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: pageMargin, bottom: 16, trailing: pageMargin))
            itemRows(header)
        }
        .listStyle(.plain)
    }

    /// The header beside the list on a wide window, and on each side of the fold in book
    /// posture; the header above the fold and the list below it in tabletop posture.
    private func splitPage(_ header: NativeMediaItem) -> some View {
        FoldSplit(fallback: .horizontal, firstWidth: 360) {
            ScrollView {
                // Beside the list, the buttons keep to the width of the artwork.
                DetailHeader(model: model, header: header, buttonsWidth: 300)
                    .padding(.horizontal, pageMargin)
                    .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
        } second: {
            List {
                itemRows(header)
                    .listSectionSeparator(.hidden, edges: .top)
            }
            .listStyle(.plain)
            .contentMargins(.top, 6, for: .scrollContent)
        }
    }

    @ViewBuilder
    private func itemRows(_ header: NativeMediaItem) -> some View {
        if model.state.itemsLoad == .loading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
                .listRowSeparator(.hidden)
        }
        let items = model.state.items
        let numbered = header.mediaType == .album
        ForEach(Array(items.enumerated()), id: \.element.key) { index, item in
            Group {
                if item.opensDetails && item.mediaType != .track {
                    NavigationLink(value: LibraryRoute.item(item)) { MediaRow(item: item) }
                } else {
                    Button { model.screen.play(item: item) } label: {
                        MediaRow(
                            item: item,
                            showsArtwork: !numbered,
                            leadingNumber: numbered ? (item.trackNumber?.intValue ?? index + 1) : nil,
                            hidesSubtitle: numbered && item.subtitle == header.subtitle
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isPlayable)
                }
            }
            .mediaRowInsets()
            .contextMenu {
                MediaContextMenu(item: item, canShuffle: false) { _ in model.screen.play(item: item) }
                if model.state.canEditLibrary && item.canBeFavorited {
                    Button(item.isFavorite ? "Remove from Favorites" : "Favorite",
                           systemImage: item.isFavorite ? "heart.slash" : "heart") {
                        model.screen.toggleFavorite(item: item)
                    }
                }
            }
        }
        if !items.isEmpty {
            DetailFooter(items: items, mediaType: header.mediaType)
                .listRowSeparator(.hidden)
                .mediaRowInsets()
        }
    }

    private var overflowMenu: some View {
        Menu {
            if let header = model.state.header {
                Button("Play", systemImage: "play.fill") { model.screen.play(shuffle: false) }
                    .disabled(!header.isPlayable)
                if model.state.canShuffle {
                    Button("Shuffle", systemImage: "shuffle") { model.screen.play(shuffle: true) }
                }
                if model.state.canEditLibrary {
                    Section {
                        if header.isInLibrary && header.canBeFavorited {
                            Button(header.isFavorite ? "Remove from Favorites" : "Favorite",
                                   systemImage: header.isFavorite ? "heart.slash" : "heart") {
                                model.screen.toggleFavorite()
                            }
                        }
                        if header.mediaType != .genre {
                            Button(header.isInLibrary ? "Remove from Library" : "Add to Library",
                                   systemImage: header.isInLibrary ? "minus.circle" : "plus.circle") {
                                model.screen.toggleLibrary()
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }
}

/// Artwork, title, subtitle and the Play and Shuffle buttons.
private struct DetailHeader: View {
    @ObservedObject var model: ItemDetailsModel
    let header: NativeMediaItem
    var buttonsWidth: CGFloat = 420

    var body: some View {
        VStack(spacing: 14) {
            ArtworkView(url: header.artworkUrl, cornerRadius: 12, placeholderSymbol: header.mediaType.librarySymbol)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: min(300, buttonsWidth))
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(header.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    if header.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.subheadline)
                            .foregroundStyle(.pink)
                            .accessibilityLabel("Favorite")
                    }
                }
                if let subtitle = header.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .multilineTextAlignment(.center)
                }
                if let detail = detailLine {
                    Text(detail)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Button {
                    model.screen.play(shuffle: false)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!header.isPlayable)
                if model.state.canShuffle {
                    Button {
                        model.screen.play(shuffle: true)
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .font(.headline)
            .frame(maxWidth: buttonsWidth)
        }
        .frame(maxWidth: .infinity)
    }

    private var detailLine: String? {
        var parts: [String] = []
        switch header.mediaType {
        case .album: parts.append("Album")
        case .playlist: parts.append("Playlist")
        case .podcast: parts.append("Podcast")
        case .audiobook: parts.append("Audiobook")
        case .genre: parts.append("Genre")
        default: break
        }
        if let year = header.year?.intValue { parts.append(String(year)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// "12 songs, 48 min" under the list.
private struct DetailFooter: View {
    let items: [NativeMediaItem]
    let mediaType: MediaType

    var body: some View {
        let total = items.compactMap(\.duration).reduce(0, +)
        let noun: String = {
            switch mediaType {
            case .podcast: return items.count == 1 ? "episode" : "episodes"
            case .genre: return items.count == 1 ? "item" : "items"
            default: return items.count == 1 ? "song" : "songs"
            }
        }()
        Text(total > 0 ? "\(items.count) \(noun), \(formatTotalDuration(total))" : "\(items.count) \(noun)")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)
    }
}

/// An artist: the round portrait, Play and Shuffle, the top songs and the album rows.
private struct ArtistPage: View {
    @ObservedObject var model: ItemDetailsModel
    let header: NativeMediaItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 14) {
                    ArtworkView(url: header.artworkUrl, cornerRadius: 110, placeholderSymbol: "music.microphone")
                        .frame(width: 220, height: 220)
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                    Text(header.title)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button { model.screen.play(shuffle: false) } label: {
                            Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        if model.state.canShuffle {
                            Button { model.screen.play(shuffle: true) } label: {
                                Label("Shuffle", systemImage: "shuffle").frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .font(.headline)
                    .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity)

                if !model.state.topTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle("Top Songs")
                        ForEach(model.state.topTracks.prefix(5), id: \.key) { track in
                            Button { model.screen.play(item: track) } label: { MediaRow(item: track) }
                                .buttonStyle(.plain)
                                .padding(.horizontal, pageMargin)
                            Divider().padding(.leading, pageMargin + 58)
                        }
                    }
                }
                AlbumRow(title: "In Your Library", items: model.state.libraryAlbums)
                AlbumRow(title: "Albums", items: model.state.allAlbums)
            }
            .padding(.vertical, 16)
        }
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title2.weight(.bold))
            .padding(.horizontal, pageMargin)
    }
}

/// A horizontally scrolling row of album tiles.
private struct AlbumRow: View {
    let title: String
    let items: [NativeMediaItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(items, id: \.key) { item in
                            NavigationLink(value: LibraryRoute.item(item)) {
                                MediaTile(item: item).frame(width: 160)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, pageMargin)
                }
            }
        }
    }
}

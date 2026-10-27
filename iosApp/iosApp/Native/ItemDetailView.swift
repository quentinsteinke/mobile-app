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
        let artists = model.state.genreArtists
        if !artists.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("media_type_artists", "Artists")).font(.title3.weight(.bold))
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(artists, id: \.key) { artist in
                            NavigationLink(value: LibraryRoute.item(artist)) { MediaTile(item: artist).frame(width: 120) }
                                .buttonStyle(.plain)
                                .contextMenu { MediaContextMenu(item: artist) }
                        }
                    }
                }
            }
            .mediaRowInsets()
            .listRowSeparator(.hidden)
        }
        let chapters = model.state.chapters
        if !chapters.isEmpty {
            Section {
                ForEach(chapters, id: \.position) { chapter in
                    Button { model.screen.playChapter(position: chapter.position) } label: {
                        HStack(spacing: 12) {
                            Text("\(chapter.position + 1)")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 24, alignment: .trailing)
                            Text(chapter.name).lineLimit(2)
                            Spacer(minLength: 8)
                            if chapter.durationSec > 0 {
                                Text(formatPlaybackTime(chapter.durationSec))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .mediaRowInsets()
                }
            } header: {
                Text(L("media_type_chapters", "Chapters")).font(.title3.weight(.bold)).foregroundStyle(.primary).textCase(nil)
            }
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
                MediaContextMenu(
                    item: item,
                    context: header.mediaType.menuContext,
                    inEditablePlaylist: model.state.isEditablePlaylist,
                    playFromHere: { model.screen.play(item: item) },
                    removeFromPlaylist: { model.screen.removeFromPlaylist(item: item) }
                )
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
                MediaContextMenu(item: header)
                if model.state.isPlaylist {
                    Button(L("refresh", "Refresh"), systemImage: "arrow.clockwise") { model.screen.refreshPlaylist() }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(L("cd_more", "More"))
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
                            .accessibilityLabel(L("action_favorite", "Favorite"))
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
                    Label(L("action_play", "Play"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!header.isPlayable)
                if model.state.canShuffle {
                    Button {
                        model.screen.play(shuffle: true)
                    } label: {
                        Label(L("media_action_shuffle", "Shuffle"), systemImage: "shuffle")
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

/// An artist: the round portrait, Play and Shuffle, the top songs, the album rows and the
/// similar artists. An artist without top songs from a provider shows its songs.
private struct ArtistPage: View {
    @ObservedObject var model: ItemDetailsModel
    let header: NativeMediaItem

    private var songs: [NativeMediaItem] {
        let top = model.state.topTracks
        return top.isEmpty ? model.state.items.filter { $0.mediaType == .track } : top
    }

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
                            Label(L("action_play", "Play"), systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        if model.state.canShuffle {
                            Button { model.screen.play(shuffle: true) } label: {
                                Label(L("media_action_shuffle", "Shuffle"), systemImage: "shuffle").frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .font(.headline)
                    .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, pageMargin)

                if !songs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(model.state.topTracks.isEmpty ? "Songs" : "Top Songs",
                                     seeAll: songs.count > 5 ? LibraryRoute.items(title: header.title, items: songs) : nil)
                        ForEach(songs.prefix(5), id: \.key) { track in
                            Button { model.screen.play(item: track) } label: { MediaRow(item: track) }
                                .buttonStyle(.plain)
                                .padding(.horizontal, pageMargin)
                                .contextMenu { MediaContextMenu(item: track) }
                            Divider().padding(.leading, pageMargin + 58)
                        }
                    }
                }
                AlbumRow(title: "In Your Library", items: model.state.libraryAlbums)
                AlbumRow(title: "Albums", items: model.state.allAlbums)
                AlbumRow(title: "Similar Artists", items: model.state.similarArtists)
            }
            .padding(.vertical, 16)
        }
        .onAppear { if model.state.similarArtistsLoad == nil { model.screen.loadSimilarArtists() } }
    }
}

private struct SectionTitle: View {
    let text: String
    var seeAll: LibraryRoute?

    init(_ text: String, seeAll: LibraryRoute? = nil) {
        self.text = text
        self.seeAll = seeAll
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.title2.weight(.bold))
            Spacer()
            if let seeAll {
                NavigationLink("See All", value: seeAll)
                    .font(.body)
            }
        }
        .padding(.horizontal, pageMargin)
    }
}

/// A horizontally scrolling row of tiles.
private struct AlbumRow: View {
    let title: String
    let items: [NativeMediaItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title, seeAll: items.count > 6 ? LibraryRoute.items(title: title, items: items) : nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(items, id: \.key) { item in
                            NavigationLink(value: LibraryRoute.item(item)) {
                                MediaTile(item: item).frame(width: 160)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { MediaContextMenu(item: item) }
                        }
                    }
                    .padding(.horizontal, pageMargin)
                }
            }
        }
    }
}

/// A list that a page already loaded, shown in full: the songs or the albums of an artist.
struct ItemsListView: View {
    let title: String
    let items: [NativeMediaItem]
    var bottomInset: CGFloat = 0

    var body: some View {
        Group {
            if items.contains(where: { $0.mediaType != .track }) {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 16)], spacing: 20) {
                        ForEach(items, id: \.key) { item in
                            NavigationLink(value: LibraryRoute.item(item)) { MediaTile(item: item) }
                                .buttonStyle(.plain)
                                .contextMenu { MediaContextMenu(item: item) }
                        }
                    }
                    .padding(.horizontal, pageMargin)
                }
            } else {
                List(items, id: \.key) { item in
                    Button { NativeActions.shared.perform(item: item, action: .playNow) } label: { MediaRow(item: item) }
                        .buttonStyle(.plain)
                        .mediaRowInsets()
                        .listSectionSeparator(.hidden, edges: .top)
                        .contextMenu { MediaContextMenu(item: item) }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaPadding(.bottom, bottomInset)
    }
}

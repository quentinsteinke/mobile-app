import SwiftUI
import ComposeApp

/// A grid tile: square artwork with the title and subtitle under it.
struct MediaTile: View {
    let item: NativeMediaItem

    var body: some View {
        let round = item.mediaType == .artist
        VStack(alignment: round ? .center : .leading, spacing: 6) {
            ArtworkView(url: item.artworkUrl, cornerRadius: round ? 0 : 10, placeholderSymbol: item.mediaType.librarySymbol)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(round ? AnyShape(Circle()) : AnyShape(Rectangle()))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            VStack(alignment: round ? .center : .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if item.isExplicit { ExplicitBadge() }
                }
                Text(item.subtitle ?? (item.year.map { String($0.intValue) } ?? " "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

/// A list row: artwork (round for an artist), title, subtitle and duration.
struct MediaRow: View {
    let item: NativeMediaItem
    var showsArtwork = true
    var leadingNumber: Int?
    /// Hides the subtitle, as on an album page where every track has the album's artist.
    var hidesSubtitle = false

    var body: some View {
        HStack(spacing: 12) {
            if let leadingNumber {
                Text("\(leadingNumber)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
            } else if showsArtwork {
                ArtworkView(
                    url: item.artworkUrl,
                    cornerRadius: item.mediaType == .artist ? 26 : 6,
                    placeholderSymbol: item.mediaType.librarySymbol
                )
                .frame(width: item.mediaType == .artist ? 52 : 46, height: item.mediaType == .artist ? 52 : 46)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .lineLimit(1)
                    if item.isExplicit { ExplicitBadge() }
                }
                if !hidesSubtitle, let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let duration = item.duration, duration > 0 {
                Text(formatPlaybackTime(duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(item.isPlayable || item.opensDetails ? 1 : 0.45)
        .contentShape(Rectangle())
    }
}

/// The "E" badge of explicit content.
struct ExplicitBadge: View {
    var body: some View {
        Image(systemName: "e.square.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Explicit")
    }
}

/// The long-press menu of a list item.
struct MediaContextMenu: View {
    let item: NativeMediaItem
    let canShuffle: Bool
    let play: (_ shuffle: Bool) -> Void

    var body: some View {
        if item.isPlayable || item.opensDetails {
            Button("Play", systemImage: "play.fill") { play(false) }
            if canShuffle && item.canPlayShuffled {
                Button("Shuffle", systemImage: "shuffle") { play(true) }
            }
        }
    }
}

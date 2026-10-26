import SwiftUI
import ComposeApp

/// The glass mini player above the tab bar. A tap opens Now Playing.
struct MiniPlayer: View {
    @ObservedObject var model: PlayerModel
    let nowPlaying: NativeNowPlaying

    var body: some View {
        HStack(spacing: 4) {
            Button {
                model.isNowPlayingPresented = true
            } label: {
                HStack(spacing: 12) {
                    ArtworkView(url: nowPlaying.artworkUrl, cornerRadius: 8)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(nowPlaying.title ?? NativeStrings.notPlaying)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(nowPlaying.subtitle ?? nowPlaying.playerName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .accessibilityHint(NativeStrings.openNowPlaying)
            PlayPauseButton(nowPlaying: nowPlaying, size: 20)
                .frame(width: 40, height: 40)
            Button {
                NativePlayer.shared.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18))
                    .frame(width: 36, height: 40)
            }
            .disabled(!nowPlaying.canNext)
            .accessibilityLabel(NativeStrings.next)
        }
        .buttonStyle(.plain)
        .padding(.leading, 9)
        .padding(.trailing, 10)
        .frame(maxHeight: .infinity)
        .glassBackground(in: Capsule())
    }
}

/// Play, pause or stop the selected player, a power button while it is off, and a spinner
/// while a play request waits.
struct PlayPauseButton: View {
    let nowPlaying: NativeNowPlaying
    var size: CGFloat

    var body: some View {
        Button {
            if nowPlaying.isPoweredOff {
                NativePlayer.shared.powerOn()
            } else {
                NativePlayer.shared.togglePlayPause()
            }
        } label: {
            ZStack {
                if nowPlaying.isPending {
                    ProgressView()
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: size, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .disabled(!nowPlaying.canPlay && !nowPlaying.isPoweredOff)
        .accessibilityLabel(accessibilityLabel)
    }

    private var symbol: String {
        if nowPlaying.isPoweredOff { return "power" }
        if nowPlaying.showsStop { return "stop.fill" }
        return nowPlaying.isPlaying ? "pause.fill" : "play.fill"
    }

    private var accessibilityLabel: String {
        if nowPlaying.isPoweredOff { return NativeStrings.powerOn }
        if nowPlaying.showsStop { return NativeStrings.stop }
        return nowPlaying.isPlaying ? NativeStrings.pause : NativeStrings.play
    }
}

/// The user-facing text of the native UI. English for now; it moves to a localized catalog
/// when the native screens replace the Compose ones.
enum NativeStrings {
    static let notPlaying = "Not Playing"
    static let openNowPlaying = "Opens Now Playing"
    static let play = "Play"
    static let pause = "Pause"
    static let stop = "Stop"
    static let powerOn = "Turn on"
    static let next = "Next"
    static let previous = "Previous"
    static let skipBack = "Back 10 seconds"
    static let skipForward = "Forward 30 seconds"
    static let shuffle = "Shuffle"
    static let repeatMode = "Repeat"
    static let mute = "Mute"
    static let unmute = "Unmute"
    static let volume = "Volume"
    static let favorite = "Favorite"
    static let unfavorite = "Remove from favorites"
    static let upNext = "Up Next"
    static let queue = "Queue"
    static let clearQueue = "Clear Queue"
    static let remove = "Remove"
    static let queueEmpty = "Queue Is Empty"
    static let queueEmptyHint = "Play something from your library."
    static let noPlayer = "No Player"
    static let noPlayerHint = "Music Assistant has no player to play on."
    static let players = "Players"
    static let close = "Close"
}

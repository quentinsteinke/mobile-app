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

/// The text of [key] in the app's strings (`composeResources/values/strings.xml`), in the app
/// language, or [english] before the strings load or when the key has no translation.
func L(_ key: String, _ english: String) -> String {
    NativeText.shared.text(key: key) ?? english
}

/// The user-facing text of the native player. Entries with a key come from the app strings, so
/// they are translated; the others are English until they get a key.
enum NativeStrings {
    static let notPlaying = "Not Playing"
    static let openNowPlaying = "Opens Now Playing"
    static var play: String { L("action_play", "Play") }
    static var pause: String { L("action_pause", "Pause") }
    static var stop: String { L("action_stop", "Stop") }
    static let powerOn = "Turn on"
    static var next: String { L("media_action_next", "Next") }
    static var previous: String { L("media_action_previous", "Previous") }
    static let skipBack = "Back 10 seconds"
    static let skipForward = "Forward 30 seconds"
    static var shuffle: String { L("media_action_shuffle", "Shuffle") }
    static var repeatMode: String { L("media_action_repeat", "Repeat") }
    static var mute: String { L("cd_mute", "Mute") }
    static var unmute: String { L("cd_unmute", "Unmute") }
    static let volume = "Volume"
    static var favorite: String { L("action_favorite", "Favorite") }
    static var unfavorite: String { L("action_unfavorite", "Remove from favorites") }
    static let upNext = "Up Next"
    static var queue: String { L("queue_label", "Queue") }
    static var clearQueue: String { L("queue_clear", "Clear Queue") }
    static var remove: String { L("action_remove", "Remove") }
    static var queueEmpty: String { L("queue_empty", "Queue Is Empty") }
    static let queueEmptyHint = "Play something from your library."
    static let noPlayer = "No Player"
    static let noPlayerHint = "Music Assistant has no player to play on."
    static var players: String { L("players_title", "Players") }
    static var close: String { L("cd_close", "Close") }
}

import SwiftUI
import ComposeApp

/// The native Now Playing screen: artwork on a background tinted by it, the title, a scrubber,
/// the transport controls, volume, favorite, the player choice and the queue. A wide window
/// (the unfolded iPhone Duo, landscape) puts the artwork or the queue beside the controls.
struct NowPlayingView: View {
    @ObservedObject var model: PlayerModel
    @State private var showsQueue = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NowPlayingBackground(url: model.current?.artworkUrl)
                if let nowPlaying = model.current {
                    if geometry.size.width > geometry.size.height {
                        wideLayout(nowPlaying)
                    } else {
                        tallLayout(nowPlaying)
                    }
                } else {
                    ContentUnavailableView(
                        NativeStrings.noPlayer,
                        systemImage: "hifispeaker.slash",
                        description: Text(NativeStrings.noPlayerHint)
                    )
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
    }

    private func tallLayout(_ nowPlaying: NativeNowPlaying) -> some View {
        VStack(spacing: 20) {
            if showsQueue {
                QueueView(nowPlaying: nowPlaying)
                    .transition(.opacity)
            } else {
                Spacer(minLength: 8)
                ArtworkCard(nowPlaying: nowPlaying)
                    .frame(maxWidth: 420)
                    .transition(.opacity)
                Spacer(minLength: 8)
            }
            ControlsColumn(model: model, nowPlaying: nowPlaying, showsQueue: $showsQueue)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .animation(.smooth, value: showsQueue)
    }

    private func wideLayout(_ nowPlaying: NativeNowPlaying) -> some View {
        HStack(spacing: 40) {
            Group {
                if showsQueue {
                    QueueView(nowPlaying: nowPlaying)
                } else {
                    ArtworkCard(nowPlaying: nowPlaying)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            ControlsColumn(model: model, nowPlaying: nowPlaying, showsQueue: $showsQueue)
                .frame(maxWidth: 460)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .animation(.smooth, value: showsQueue)
    }
}

/// The artwork, which shrinks a little while the player is paused, as in Apple Music.
private struct ArtworkCard: View {
    let nowPlaying: NativeNowPlaying

    var body: some View {
        ArtworkView(url: nowPlaying.artworkUrl, cornerRadius: 14, placeholderSymbol: "music.note")
            .aspectRatio(1, contentMode: .fit)
            .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
            .scaleEffect(nowPlaying.isPlaying ? 1 : 0.86)
            .animation(.spring(duration: 0.45, bounce: 0.25), value: nowPlaying.isPlaying)
    }
}

/// The title, the scrubber, the transport, volume and the bottom row.
private struct ControlsColumn: View {
    @ObservedObject var model: PlayerModel
    let nowPlaying: NativeNowPlaying
    @Binding var showsQueue: Bool

    var body: some View {
        VStack(spacing: 22) {
            TitleRow(nowPlaying: nowPlaying)
            Scrubber(nowPlaying: nowPlaying, position: model.position)
            TransportRow(nowPlaying: nowPlaying)
            if nowPlaying.canSetVolume, let volume = nowPlaying.volume?.doubleValue {
                VolumeRow(nowPlaying: nowPlaying, volume: volume)
            }
            BottomRow(players: model.state.players, nowPlaying: nowPlaying, showsQueue: $showsQueue)
        }
    }
}

private struct TitleRow: View {
    let nowPlaying: NativeNowPlaying

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(nowPlaying.title ?? NativeStrings.notPlaying)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                if let subtitle = nowPlaying.subtitle {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if nowPlaying.canFavorite {
                let liked = nowPlaying.favorite?.boolValue == true
                Button {
                    NativePlayer.shared.toggleFavorite()
                } label: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.12), in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: liked)
                .accessibilityLabel(liked ? NativeStrings.unfavorite : NativeStrings.favorite)
            }
        }
    }
}

/// The playback position with the elapsed and remaining time. While the finger drags, the
/// thumb follows it; on release it seeks, and the thumb stays at the target until the player
/// reports a position near it.
private struct Scrubber: View {
    let nowPlaying: NativeNowPlaying
    let position: Double

    @State private var dragValue: Double?
    @State private var pendingSeek: Double?

    var body: some View {
        let duration = nowPlaying.durationSec?.doubleValue
        let shown = dragValue ?? pendingSeek ?? position
        VStack(spacing: 6) {
            if let duration, nowPlaying.isSeekable {
                Slider(
                    value: Binding(get: { min(shown, duration) }, set: { dragValue = $0 }),
                    in: 0...max(duration, 1)
                ) { editing in
                    guard !editing, let target = dragValue else { return }
                    pendingSeek = target
                    dragValue = nil
                    NativePlayer.shared.seek(seconds: target)
                }
                .tint(.white)
            } else {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: 4)
                    .padding(.vertical, 12)
            }
            HStack {
                Text(formatPlaybackTime(shown))
                Spacer()
                Text(duration.map { "-" + formatPlaybackTime(max(0, $0 - shown)) } ?? "∞")
            }
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(.secondary)
        }
        .onChange(of: position) { _, newPosition in
            if let target = pendingSeek, abs(newPosition - target) < 2 { pendingSeek = nil }
        }
        .onChange(of: nowPlaying.queueItemId) { _, _ in
            dragValue = nil
            pendingSeek = nil
        }
    }
}

private struct TransportRow: View {
    let nowPlaying: NativeNowPlaying

    var body: some View {
        HStack {
            if nowPlaying.isLongForm {
                transportButton("gobackward.10", label: NativeStrings.skipBack, enabled: nowPlaying.canPrevious) {
                    NativePlayer.shared.skipBack()
                }
            } else {
                ToggleButton(
                    symbol: "shuffle",
                    isOn: nowPlaying.shuffleEnabled,
                    enabled: nowPlaying.canShuffle,
                    label: NativeStrings.shuffle
                ) { NativePlayer.shared.toggleShuffle() }
            }
            Spacer()
            transportButton("backward.fill", label: NativeStrings.previous, enabled: nowPlaying.canPrevious) {
                NativePlayer.shared.previous()
            }
            Spacer()
            PlayPauseButton(nowPlaying: nowPlaying, size: 38)
                .frame(width: 72, height: 72)
            Spacer()
            transportButton("forward.fill", label: NativeStrings.next, enabled: nowPlaying.canNext) {
                NativePlayer.shared.next()
            }
            Spacer()
            if nowPlaying.isLongForm {
                transportButton("goforward.30", label: NativeStrings.skipForward, enabled: nowPlaying.canNext || nowPlaying.isSeekable) {
                    NativePlayer.shared.skipForward()
                }
            } else {
                ToggleButton(
                    symbol: nowPlaying.repeatMode == .one ? "repeat.1" : "repeat",
                    isOn: nowPlaying.repeatMode == .one || nowPlaying.repeatMode == .all,
                    enabled: nowPlaying.canRepeat,
                    label: NativeStrings.repeatMode
                ) { NativePlayer.shared.toggleRepeat() }
            }
        }
        .buttonStyle(.plain)
    }

    private func transportButton(
        _ symbol: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}

/// Shuffle and repeat: a filled rounded background while on, as in Apple Music.
private struct ToggleButton: View {
    let symbol: String
    let isOn: Bool
    let enabled: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isOn ? Color.black : Color.white.opacity(0.75))
                .frame(width: 38, height: 32)
                .background(isOn ? Color.white.opacity(0.85) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentTransition(.symbolEffect(.replace))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The volume of the selected player (0 to 100). The level is sent when the finger lifts.
private struct VolumeRow: View {
    let nowPlaying: NativeNowPlaying
    let volume: Double

    @State private var dragValue: Double?

    var body: some View {
        HStack(spacing: 12) {
            Button {
                NativePlayer.shared.toggleMute()
            } label: {
                Image(systemName: nowPlaying.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(nowPlaying.isMuted ? NativeStrings.unmute : NativeStrings.mute)
            Slider(
                value: Binding(get: { dragValue ?? volume }, set: { dragValue = $0 }),
                in: 0...100
            ) { editing in
                guard !editing, let level = dragValue else { return }
                NativePlayer.shared.setVolume(level: level)
                dragValue = nil
            }
            .tint(.white)
            .accessibilityLabel(NativeStrings.volume)
            Image(systemName: "speaker.wave.3.fill")
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// The player choice and the queue toggle.
private struct BottomRow: View {
    let players: [NativePlayerChoice]
    let nowPlaying: NativeNowPlaying
    @Binding var showsQueue: Bool

    var body: some View {
        HStack {
            Menu {
                Section(NativeStrings.players) {
                    ForEach(players, id: \.playerId) { player in
                        Button {
                            NativePlayer.shared.selectPlayer(id: player.playerId)
                        } label: {
                            if player.isSelected {
                                Label(player.name, systemImage: "checkmark")
                            } else if player.isPlaying {
                                Label(player.name, systemImage: "speaker.wave.2.fill")
                            } else {
                                Text(player.name)
                            }
                        }
                    }
                }
            } label: {
                Label(nowPlaying.playerName, systemImage: nowPlaying.isLocal ? "iphone" : "hifispeaker.fill")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            Spacer()
            Button {
                showsQueue.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(showsQueue ? Color.black : Color.white)
                    .frame(width: 44, height: 36)
                    .background(showsQueue ? Color.white.opacity(0.85) : Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NativeStrings.queue)
            .accessibilityAddTraits(showsQueue ? .isSelected : [])
        }
    }
}

/// A dark, blurred copy of the artwork behind everything, so the screen takes its colors.
private struct NowPlayingBackground: View {
    let url: String?

    var body: some View {
        ZStack {
            Color.black
            ArtworkView(url: url, cornerRadius: 0, placeholderSymbol: "")
                .scaleEffect(1.6)
                .blur(radius: 70)
                .opacity(0.85)
            LinearGradient(
                colors: [.black.opacity(0.15), .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

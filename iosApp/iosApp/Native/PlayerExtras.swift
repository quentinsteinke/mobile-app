import SwiftUI
import ComposeApp

/// What Now Playing shows in place of the artwork.
enum NowPlayingPanel {
    case artwork, queue, lyrics
}

/// The options of the current item and player: lyrics, sleep timer, speed, autoplay, crossfade,
/// the album and artist pages, and the item's own menu entries.
struct PlayerOptionsMenu: View {
    let nowPlaying: NativeNowPlaying
    @Binding var panel: NowPlayingPanel
    @Binding var route: PresentedRoute?
    @Binding var showsGroup: Bool

    private var extras: NativePlayerExtras { nowPlaying.extras }

    var body: some View {
        Menu {
            if extras.lyrics != nil {
                Button {
                    panel = panel == .lyrics ? .artwork : .lyrics
                } label: {
                    Label(panel == .lyrics ? "Hide Lyrics" : "Show Lyrics", systemImage: "quote.bubble")
                }
            }
            Section {
                if extras.sleepTimerSupported { sleepTimerMenu }
                if let speed = extras.playbackSpeed?.doubleValue { speedMenu(speed) }
                if let autoplay = extras.autoplay?.boolValue {
                    Toggle(isOn: Binding(get: { autoplay }, set: { _ in NativePlayer.shared.toggleAutoplay() })) {
                        Label("Autoplay", systemImage: "infinity")
                    }
                    .disabled(!extras.canToggleAutoplay)
                }
                if let crossfade = extras.crossfade?.boolValue {
                    Toggle(isOn: Binding(get: { crossfade }, set: { _ in NativePlayer.shared.toggleCrossfade() })) {
                        Label("Crossfade", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                    .disabled(!extras.canToggleCrossfade)
                }
                if !nowPlaying.extras.group.members.isEmpty {
                    Button("Group Speakers…", systemImage: "hifispeaker.2") { showsGroup = true }
                }
            }
            PlayerToolsMenuSection()
            Section {
                if let album = extras.album {
                    Button("Go to Album", systemImage: "square.stack") { route = PresentedRoute(.item(album)) }
                }
                ForEach(extras.artists, id: \.key) { artist in
                    Button(extras.artists.count > 1 ? "Go to \(artist.title)" : "Go to Artist", systemImage: "music.microphone") {
                        route = PresentedRoute(.item(artist))
                    }
                }
            }
            if let item = extras.item {
                MediaContextMenu(item: item, showsPlayback: false)
                if extras.canStartRadio {
                    Section {
                        Button("Start Radio", systemImage: "dot.radiowaves.left.and.right") {
                            NativePlayer.shared.startRadio()
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 36)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("More")
    }

    private var sleepTimerMenu: some View {
        let remaining = extras.sleepTimerExpiresAt.map { $0.doubleValue - Date().timeIntervalSince1970 }
            .flatMap { $0 > 0 ? $0 : nil }
        return Menu {
            ForEach([15, 30, 45, 60, 120], id: \.self) { minutes in
                Button(minutes < 60 ? "\(minutes) Minutes" : minutes == 60 ? "1 Hour" : "\(minutes / 60) Hours") {
                    NativePlayer.shared.setSleepTimer(seconds: Int32(minutes * 60))
                }
            }
            if remaining != nil {
                Button("Turn Off Timer", systemImage: "moon.zzz", role: .destructive) {
                    NativePlayer.shared.clearSleepTimer()
                }
            }
        } label: {
            if let remaining {
                Label("Sleep Timer · \(formatPlaybackTime(remaining))", systemImage: "moon.fill")
            } else {
                Label("Sleep Timer", systemImage: "moon")
            }
        }
    }

    private func speedMenu(_ speed: Double) -> some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0], id: \.self) { preset in
                Button {
                    NativePlayer.shared.setPlaybackSpeed(speed: preset)
                } label: {
                    if abs(preset - speed) < 0.01 {
                        Label(formatSpeed(preset), systemImage: "checkmark")
                    } else {
                        Text(formatSpeed(preset))
                    }
                }
            }
        } label: {
            Label("Speed · \(formatSpeed(speed))", systemImage: "gauge.with.dots.needle.67percent")
        }
    }
}

func formatSpeed(_ speed: Double) -> String {
    let text = speed.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", speed)
        : String(format: "%g", speed)
    return text + "×"
}

/// A detail page opened from Now Playing, in a sheet of its own.
struct PresentedRoute: Identifiable {
    let route: LibraryRoute
    var id: LibraryRoute { route }

    init(_ route: LibraryRoute) { self.route = route }
}

struct PresentedRouteSheet: View {
    let route: LibraryRoute
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ItemDetailView(route: route, bottomInset: 0)
                .nativeDestinations(bottomInset: 0)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

/// The lyrics of the current track. Synced lyrics follow the playback position: the current
/// line is bright and stays in the middle.
struct LyricsPanel: View {
    let lyrics: NativeLyrics
    let position: Double

    var body: some View {
        if lyrics.lines.isEmpty {
            ScrollView {
                Text(lyrics.plainText ?? "")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        } else {
            let currentMs = Int64(position * 1000)
            let current = lyrics.lines.lastIndex { $0.timeMs <= currentMs }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { index, line in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(index == current ? Color.white : Color.white.opacity(0.35))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                                .onTapGesture { NativePlayer.shared.seek(seconds: Double(line.timeMs) / 1000) }
                        }
                    }
                    .padding(.vertical, 120)
                }
                .scrollIndicators(.hidden)
                .onChange(of: current) { _, index in
                    guard let index else { return }
                    withAnimation(.smooth) { proxy.scrollTo(index, anchor: .center) }
                }
                .onAppear { current.map { proxy.scrollTo($0, anchor: .center) } }
            }
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88), .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom))
        }
    }
}

/// Groups the selected player with others, with the volume of the group and of each member.
struct GroupSheet: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let nowPlaying = model.current {
                    let group = nowPlaying.extras.group
                    List {
                        if group.hasGroupVolume, let volume = group.groupVolume?.floatValue {
                            Section("Group Volume") {
                                VolumeSlider(volume: Double(volume), muted: group.groupMuted,
                                             enabled: true, canMute: true,
                                             set: { NativePlayer.shared.setGroupVolume(level: $0) },
                                             toggleMute: { NativePlayer.shared.toggleGroupMute() })
                            }
                        }
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(nowPlaying.playerName).font(.headline)
                                    Spacer()
                                    if group.canLeave {
                                        Button("Leave Group", role: .destructive) {
                                            NativePlayer.shared.leaveGroup()
                                            dismiss()
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                if let volume = group.ownVolume?.floatValue {
                                    VolumeSlider(volume: Double(volume), muted: group.ownMuted,
                                                 enabled: group.canSetOwnVolume, canMute: group.canMute,
                                                 set: { NativePlayer.shared.setOwnVolume(level: $0) },
                                                 toggleMute: { NativePlayer.shared.toggleOwnMute() })
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        Section("Speakers") {
                            ForEach(group.members, id: \.playerId) { member in
                                MemberRow(member: member)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(NativeStrings.noPlayer, systemImage: "hifispeaker.slash")
                }
            }
            .navigationTitle("Group Speakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct MemberRow: View {
    let member: NativeGroupMember

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                NativePlayer.shared.setGroupMember(playerId: member.playerId, bound: !member.isBound)
            } label: {
                HStack {
                    Image(systemName: member.isBound ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(member.isBound ? Color.accentColor : Color.secondary)
                    Text(member.name)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!member.isManageable)
            if member.isBound, let volume = member.volume?.floatValue {
                VolumeSlider(volume: Double(volume), muted: member.isMuted,
                             enabled: member.canSetVolume, canMute: true,
                             set: { NativePlayer.shared.setMemberVolume(playerId: member.playerId, level: $0) },
                             toggleMute: { NativePlayer.shared.toggleMemberMute(playerId: member.playerId, muted: member.isMuted) })
                    .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A volume slider (0 to 100) that sends the level when the finger lifts.
struct VolumeSlider: View {
    let volume: Double
    let muted: Bool
    let enabled: Bool
    let canMute: Bool
    let set: (Double) -> Void
    let toggleMute: () -> Void

    @State private var dragValue: Double?

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggleMute) {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.fill")
                    .frame(width: 24)
            }
            .buttonStyle(.borderless)
            .disabled(!canMute)
            .accessibilityLabel(muted ? NativeStrings.unmute : NativeStrings.mute)
            Slider(value: Binding(get: { dragValue ?? volume }, set: { dragValue = $0 }), in: 0...100) { editing in
                guard !editing, let level = dragValue else { return }
                set(level)
                dragValue = nil
            }
            .disabled(!enabled)
            .accessibilityLabel(NativeStrings.volume)
            Text("\(Int((dragValue ?? volume).rounded()))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

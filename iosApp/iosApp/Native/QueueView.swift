import SwiftUI
import ComposeApp

/// The queue of the selected player. A tap plays an item, a swipe removes it, and Edit lets the
/// user reorder the items.
struct QueueView: View {
    let nowPlaying: NativeNowPlaying
    @State private var editMode: EditMode = .inactive

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NativeStrings.upNext)
                    .font(.headline)
                Spacer()
                if !nowPlaying.queue.isEmpty {
                    EditButton()
                        .font(.subheadline.weight(.semibold))
                    Menu {
                        Button(NativeStrings.clearQueue, systemImage: "trash", role: .destructive) {
                            NativePlayer.shared.clearQueue()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 36, height: 30)
                    }
                }
            }
            .padding(.horizontal, 4)
            if nowPlaying.queue.isEmpty {
                ContentUnavailableView(
                    NativeStrings.queueEmpty,
                    systemImage: "music.note.list",
                    description: Text(NativeStrings.queueEmptyHint)
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(nowPlaying.queue, id: \.queueItemId) { item in
                        QueueRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !item.isCurrent, item.isPlayable, !editMode.isEditing else { return }
                                NativePlayer.shared.playQueueItem(queueItemId: item.queueItemId)
                            }
                            .listRowBackground(item.isCurrent ? Color.white.opacity(0.1) : Color.clear)
                            .listRowSeparatorTint(.white.opacity(0.15))
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            NativePlayer.shared.removeQueueItem(queueItemId: nowPlaying.queue[index].queueItemId)
                        }
                    }
                    .onMove { sources, destination in
                        guard let from = sources.first else { return }
                        let to = destination > from ? destination - 1 : destination
                        NativePlayer.shared.moveQueueItem(
                            queueItemId: nowPlaying.queue[from].queueItemId,
                            from: Int32(from),
                            to: Int32(to)
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
            }
        }
    }
}

private struct QueueRow: View {
    let item: NativeQueueItem

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: item.artworkUrl, cornerRadius: 6)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(item.isCurrent ? .semibold : .regular))
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if item.isCurrent {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                    .foregroundStyle(.secondary)
            } else if let duration = item.durationSec?.doubleValue {
                Text(formatPlaybackTime(duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(item.isPlayable ? 1 : 0.4)
    }
}

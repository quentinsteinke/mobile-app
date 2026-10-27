import SwiftUI
import ComposeApp

/// The parts of a long-press action that need a screen of their own: the playlist chooser, the
/// confirmation before removing from the library, and the toasts. The shell presents them, so a
/// menu in any tab can ask for them.
@MainActor
final class ItemActionsModel: ObservableObject {
    static let shared = ItemActionsModel()

    @Published var playlistTarget: NativeMediaItem?
    @Published var removalTarget: NativeMediaItem?
    @Published private(set) var toast: String?
    private var toastTask: Task<Void, Never>?
    private var subscription: Task<Void, Never>?

    private init() {
        subscription = Task { [weak self] in
            for await message in NativeActions.shared.toasts { self?.show(message) }
        }
    }

    func show(_ message: String) {
        toastTask?.cancel()
        withAnimation(.snappy) { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { self?.toast = nil }
        }
    }

    func perform(_ action: NativeAction, on item: NativeMediaItem) {
        switch action {
        case .addToPlaylist: playlistTarget = item
        case .removeFromLibrary: removalTarget = item
        default: NativeActions.shared.perform(item: item, action: action)
        }
    }
}

/// The long-press menu of a row or tile: the play entries, then the library, favorite and
/// playlist entries, as in the Compose menus. [playFromHere] and [removeFromPlaylist] come from
/// the page that lists the item.
struct MediaContextMenu: View {
    let item: NativeMediaItem
    var context: NativeMenuContext = .list
    var inEditablePlaylist = false
    var playFromHere: (() -> Void)?
    var removeFromPlaylist: (() -> Void)?

    var body: some View {
        let actions = NativeActions.shared.menu(item: item, context: context, inEditablePlaylist: inEditablePlaylist)
            .filter { $0 != .playFromHere || playFromHere != nil }
        Section {
            ForEach(actions.filter(\.plays), id: \.self, content: button)
        }
        Section {
            ForEach(actions.filter { !$0.plays }, id: \.self, content: button)
        }
    }

    private func button(_ action: NativeAction) -> some View {
        Button(role: action.isDestructive ? .destructive : nil) {
            switch action {
            case .playFromHere: playFromHere?()
            case .removeFromPlaylist: removeFromPlaylist?()
            default: ItemActionsModel.shared.perform(action, on: item)
            }
        } label: {
            Label(NativeActions.shared.title(action: action, context: context), systemImage: action.symbol)
        }
    }
}

extension NativeAction {
    var symbol: String {
        switch self {
        case .playNow: "play.fill"
        case .playNextAndPlay: "play.square.stack"
        case .playNext: "text.line.first.and.arrowtriangle.forward"
        case .addToQueue: "text.line.last.and.arrowtriangle.forward"
        case .replaceNext: "text.badge.xmark"
        case .playFromHere: "play.circle"
        case .playShuffled: "shuffle"
        case .playFromBeginning: "backward.end"
        case .startRadio: "dot.radiowaves.left.and.right"
        case .addToLibrary: "plus"
        case .removeFromLibrary: "trash"
        case .favorite: "heart"
        case .unfavorite: "heart.slash"
        case .dislike: "hand.thumbsdown"
        case .removeDislike: "hand.thumbsdown.slash"
        case .addToPlaylist: "text.badge.plus"
        case .removeFromPlaylist: "minus.circle"
        case .markPlayed: "checkmark.circle"
        case .markUnplayed: "arrow.counterclockwise.circle"
        }
    }

    var isDestructive: Bool { self == .removeFromLibrary || self == .removeFromPlaylist }
}

/// Chooses the playlist to add an item to, or creates one.
struct AddToPlaylistSheet: View {
    let item: NativeMediaItem
    @Environment(\.dismiss) private var dismiss
    @State private var playlists: [NativeMediaItem]?
    @State private var newName = ""
    @State private var isCreating = false
    @State private var asksName = false

    var body: some View {
        NavigationStack {
            Group {
                if let playlists {
                    List {
                        Section {
                            Button { asksName = true } label: {
                                Label("New Playlist…", systemImage: "plus")
                            }
                            .disabled(isCreating)
                        }
                        Section {
                            ForEach(playlists, id: \.key) { playlist in
                                Button {
                                    NativeActions.shared.addToPlaylist(item: item, playlist: playlist)
                                    dismiss()
                                } label: {
                                    MediaRow(item: playlist)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .overlay {
                        if playlists.isEmpty && !isCreating {
                            ContentUnavailableView("No Playlists", systemImage: "music.note.list",
                                                   description: Text("Create one to add \(item.title) to it."))
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .alert("New Playlist", isPresented: $asksName) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { newName = "" }
                Button("Create") { create() }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .task { await load() }
    }

    private func load() async {
        playlists = (try? await NativeActions.shared.editablePlaylists(item: item)) ?? []
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        newName = ""
        guard !name.isEmpty else { return }
        isCreating = true
        Task {
            if let created = try? await NativeActions.shared.createPlaylist(name: name) {
                NativeActions.shared.addToPlaylist(item: item, playlist: created)
                dismiss()
            }
            isCreating = false
        }
    }
}

/// A short message at the top of the screen, for the result of an action.
struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassBackground(in: Capsule())
            .padding(.horizontal, 24)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
    }
}

extension View {
    /// The playlist chooser, the removal confirmation and the toasts of the long-press menus.
    func itemActionPresentations() -> some View {
        modifier(ItemActionPresentations())
    }
}

private struct ItemActionPresentations: ViewModifier {
    @ObservedObject private var model = ItemActionsModel.shared

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.playlistTarget) { item in
                AddToPlaylistSheet(item: item)
            }
            .confirmationDialog(
                "Remove from Library?",
                isPresented: Binding(get: { model.removalTarget != nil }, set: { if !$0 { model.removalTarget = nil } }),
                titleVisibility: .visible,
                presenting: model.removalTarget
            ) { item in
                Button("Remove \(item.title)", role: .destructive) {
                    NativeActions.shared.perform(item: item, action: .removeFromLibrary)
                }
            }
            .overlay(alignment: .top) {
                if let toast = model.toast {
                    ToastBanner(message: toast).padding(.top, 8)
                }
            }
    }
}

extension NativeMediaItem: @retroactive Identifiable {
    public var id: String { key }
}

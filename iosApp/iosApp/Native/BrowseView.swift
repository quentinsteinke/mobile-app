import SwiftUI
import ComposeApp

@MainActor
final class BrowseModel: ObservableObject {
    @Published private(set) var state: NativeBrowseState
    let screen: NativeBrowse
    private var task: Task<Void, Never>?

    init(path: String?) {
        screen = NativeBrowse(path: path)
        state = screen.state.value
        task = Task { [weak self, screen] in
            for await value in screen.state { self?.state = value }
        }
    }

    deinit {
        task?.cancel()
        screen.close()
    }
}

/// One level of the server's Browse tree: folders open the next level, items open their page
/// or play.
struct BrowseView: View {
    let path: String?
    let title: String
    var bottomInset: CGFloat = 0

    @StateObject private var model: BrowseModel

    init(path: String?, title: String, bottomInset: CGFloat) {
        self.path = path
        self.title = title
        self.bottomInset = bottomInset
        _model = StateObject(wrappedValue: BrowseModel(path: path))
    }

    var body: some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(path == nil ? .large : .inline)
            .safeAreaPadding(.bottom, bottomInset)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state.load {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            ContentUnavailableView {
                Label("Couldn't Browse", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Try Again") { model.screen.reload() }
            }
        case .empty:
            ContentUnavailableView("Empty Folder", systemImage: "folder")
        default:
            List(model.state.items, id: \.key) { item in
                row(item)
                    .mediaRowInsets()
                    .listSectionSeparator(.hidden, edges: .top)
            }
            .listStyle(.plain)
            .refreshable { model.screen.reload() }
        }
    }

    @ViewBuilder
    private func row(_ item: NativeMediaItem) -> some View {
        if let folder = item.browsePath {
            NavigationLink(value: LibraryRoute.browse(path: folder, title: item.title)) {
                FolderRow(item: item)
            }
        } else if item.opensDetails {
            NavigationLink(value: LibraryRoute.item(item)) { MediaRow(item: item) }
                .contextMenu { MediaContextMenu(item: item) }
        } else {
            Button { model.screen.play(item: item) } label: { MediaRow(item: item) }
                .buttonStyle(.plain)
                .disabled(!item.isPlayable)
                .contextMenu { MediaContextMenu(item: item) }
        }
    }
}

private struct FolderRow: View {
    let item: NativeMediaItem

    var body: some View {
        HStack(spacing: 12) {
            if item.artworkUrl != nil {
                ArtworkView(url: item.artworkUrl, cornerRadius: 6, placeholderSymbol: "folder")
                    .frame(width: 46, height: 46)
            } else {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 46, height: 46)
            }
            Text(item.title).lineLimit(1)
        }
    }
}

@MainActor
final class AiRadioModel: ObservableObject {
    @Published private(set) var state: NativeAiRadioState
    let screen = NativeAiRadio()
    private var task: Task<Void, Never>?

    init() {
        state = screen.state.value
        task = Task { [weak self, screen] in
            for await value in screen.state { self?.state = value }
        }
    }

    deinit {
        task?.cancel()
        screen.close()
    }
}

/// The AI Radio stations. A tap plays a station on the selected player.
struct AiRadioView: View {
    var bottomInset: CGFloat = 0
    @StateObject private var model = AiRadioModel()

    var body: some View {
        content
            .navigationTitle("AI Radio")
            .safeAreaPadding(.bottom, bottomInset)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state.load {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            ContentUnavailableView {
                Label("Couldn't Load AI Radio", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Try Again") { model.screen.reload() }
            }
        case .empty:
            ContentUnavailableView("No Stations", systemImage: "dot.radiowaves.left.and.right",
                                   description: Text("Create a station in the Music Assistant web app."))
        default:
            List {
                if !model.state.hasTargetPlayer {
                    Text("Choose a player to play a station on.")
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }
                ForEach(model.state.stations, id: \.id) { station in
                    Button { model.screen.play(stationId: station.id) } label: {
                        HStack(spacing: 12) {
                            ArtworkView(url: station.artworkUrl, cornerRadius: 6, placeholderSymbol: "dot.radiowaves.left.and.right")
                                .frame(width: 46, height: 46)
                            Text(station.name).lineLimit(1)
                            Spacer()
                            Image(systemName: "play.circle")
                                .font(.title3)
                                .foregroundStyle(.tint)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.state.hasTargetPlayer)
                    .mediaRowInsets()
                }
            }
            .listStyle(.plain)
            .refreshable { model.screen.reload() }
        }
    }
}

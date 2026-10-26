import SwiftUI
import UIKit
import ComposeApp

/// Artwork from the shared Kotlin artwork repository (`NativeArtworkLoader`), so it uses the same
/// cache, freshness and WebRTC routing as the rest of the app. Shows a placeholder until it loads.
struct ArtworkView: View {
    let url: String?
    var cornerRadius: CGFloat = 8
    var placeholderSymbol = "music.note"

    @StateObject private var loader = ArtworkLoader()

    var body: some View {
        ZStack {
            Rectangle().fill(Color(uiColor: .tertiarySystemFill))
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { loader.load(url) }
        .onChange(of: url) { _, newURL in loader.load(newURL) }
        .onDisappear { loader.cancel() }
    }
}

/// Loads one artwork URL at a time and drops the result of a URL that is no longer wanted.
@MainActor
final class ArtworkLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    private var url: String?
    private var request: ComposeApp.Cancellable?

    func load(_ newURL: String?) {
        guard newURL != url || image == nil else { return }
        request?.cancel()
        url = newURL
        image = nil
        guard let newURL, !newURL.isEmpty else { return }
        request = NativeArtworkLoader.loadArtwork(urlString: newURL) { [weak self] loaded in
            guard let self, self.url == newURL else { return }
            self.image = loaded
        }
    }

    func cancel() {
        request?.cancel()
        request = nil
    }
}

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
        // The image fills an overlay of a color, so it never asks for more than the space it
        // gets: an aspect-filled image on its own reports the larger, filled size.
        Rectangle()
            .fill(Color(uiColor: .tertiarySystemFill))
            .overlay {
                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if !placeholderSymbol.isEmpty {
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

    /// Keeps the previous image until the new one arrives, so a track change does not flash
    /// the placeholder.
    func load(_ newURL: String?) {
        guard newURL != url || image == nil else { return }
        request?.cancel()
        url = newURL
        guard let newURL, !newURL.isEmpty else {
            image = nil
            return
        }
        request = NativeArtworkLoader.loadArtwork(urlString: newURL) { [weak self] loaded in
            guard let self, self.url == newURL else { return }
            withAnimation(.easeInOut(duration: 0.3)) { self.image = loaded }
        }
    }

    func cancel() {
        request?.cancel()
        request = nil
    }
}

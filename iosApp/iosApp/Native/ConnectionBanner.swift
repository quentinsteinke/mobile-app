import SwiftUI
import ComposeApp

/// The reconnect state for the native shell. The banner shows after a short delay, so a quick
/// reconnect does not flash it, as in Compose.
@MainActor
final class ConnectionModel: ObservableObject {
    static let shared = ConnectionModel()

    @Published private(set) var banner: String?
    private var shown: String?
    private var tasks: [Task<Void, Never>] = []
    private var delay: Task<Void, Never>?

    private init() {
        tasks = [Task { [weak self] in
            for await text in NativeConnection.shared.banner { self?.update(text) }
        }]
    }

    private func update(_ text: String?) {
        shown = text
        guard let text else {
            delay?.cancel()
            delay = nil
            withAnimation(.snappy) { banner = nil }
            return
        }
        if banner != nil {
            banner = text
            return
        }
        guard delay == nil else { return }
        delay = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.delay = nil
            withAnimation(.snappy) { self.banner = self.shown }
        }
    }
}

/// "Reconnecting…" at the top of the shell, with a button that stops it.
struct ConnectionBanner: View {
    @ObservedObject private var model = ConnectionModel.shared

    var body: some View {
        if let text = model.banner {
            HStack(spacing: 12) {
                ProgressView()
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button("Stop", role: .destructive) { NativeConnection.shared.stop() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassBackground(in: Capsule())
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

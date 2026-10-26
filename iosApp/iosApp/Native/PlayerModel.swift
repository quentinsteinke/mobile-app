import SwiftUI
import ComposeApp

/// The native player state for SwiftUI, from the Kotlin `NativePlayer` bridge. It follows the
/// selected player and its playback position, which ticks while the player plays.
@MainActor
final class PlayerModel: ObservableObject {
    static let shared = PlayerModel()

    @Published private(set) var state: NativePlayerState
    /// Elapsed seconds of the current item.
    @Published private(set) var position: Double = 0
    @Published var isNowPlayingPresented = false

    private var positionQueueId: String?
    private var positionTask: Task<Void, Never>?

    var current: NativeNowPlaying? { state.current }

    private init() {
        state = NativePlayer.shared.state.value
        follow(state)
        Task { [weak self] in
            for await state in NativePlayer.shared.state {
                self?.follow(state)
            }
        }
    }

    private func follow(_ newState: NativePlayerState) {
        state = newState
        let queueId = newState.current?.queueId
        guard queueId != positionQueueId else { return }
        positionQueueId = queueId
        positionTask?.cancel()
        position = newState.current?.elapsedSec?.doubleValue ?? 0
        guard let queueId else { return }
        positionTask = Task { [weak self] in
            for await seconds in NativePlayer.shared.position(queueId: queueId) {
                self?.position = seconds.doubleValue
            }
        }
    }
}

/// Elapsed or remaining time as "m:ss", or "h:mm:ss" from an hour on.
func formatPlaybackTime(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, secs)
        : String(format: "%d:%02d", minutes, secs)
}

extension View {
    /// Liquid Glass on iOS 26 and later, a material on earlier versions.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}

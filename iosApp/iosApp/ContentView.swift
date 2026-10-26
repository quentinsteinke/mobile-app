import UIKit
import SwiftUI
import ComposeApp

struct ComposeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = MainViewControllerKt.MainViewController()
        // Compose moves its content up above the keyboard. Clip it to the view, so it does
        // not slide under the status bar.
        controller.view.clipsToBounds = true
        FoldStateBridge.attach(to: controller.view)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// The app shell: a native `TabView` around one Compose view.
///
/// The tabs are SwiftUI, so the system lays them out: a sidebar on a wide display (the inner
/// display of iPhone Duo), a tab bar on a narrow one, and on the iOS 27.1 SDK the vertical bar
/// below the status bar of the folded Duo. The content is the existing Compose UI. One Compose
/// view sits above the tab view, sized to the content area of the open tab, and Compose renders
/// that tab. Moving one view between tabs, or a Compose view for each tab, would restart the
/// Compose lifecycle on every tab switch, and the app disconnects from the server when the
/// lifecycle stops.
///
/// Kotlin owns the tab state (`IosTabShell`): the shell shows the tabs while the main screen is
/// on, and only the Compose view on the settings and connection screen. A tab tap goes back to
/// Kotlin, which switches the tab, so back stacks and deep links work as before.
///
/// Compose stays inside the safe area, so nothing goes under the status bar, the home indicator,
/// or the vertical status bar of iPhone Duo. Only the background fills the screen edges, in the
/// system color that the iOS Compose theme also uses.
struct ContentView: View {
    @StateObject private var shell = TabShellModel()
    @State private var composeFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let state = shell.state, state.active {
                TabView(selection: tabSelection(state)) {
                    ForEach(Array(state.tabs.enumerated()), id: \.offset) { index, tab in
                        Tab(tab.title, systemImage: tab.symbol, value: index) {
                            ComposeFrameReader(frame: $composeFrame)
                                // The expanded player covers the content, as in Compose.
                                .toolbarVisibility(state.playerExpanded ? .hidden : .automatic, for: .tabBar)
                        }
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                // The tab bar and the sidebar lay out to the screen edges; the tab contents still
                // get the safe area.
                .ignoresSafeArea()
            } else {
                ComposeFrameReader(frame: $composeFrame)
            }
        }
        // An overlay, so the size of the Compose view never changes the layout that the readers
        // measure. As a sibling in the stack it fed back into the measured area, and on iPhone
        // Duo the two never settled.
        .overlay(alignment: .topLeading) {
            ComposeView()
                .ignoresSafeArea(.keyboard) // Compose has its own keyboard handling
                .frame(width: composeFrame.width, height: composeFrame.height)
                .clipped()
                .offset(x: composeFrame.minX, y: composeFrame.minY)
        }
        // ComposeFrameReader reports in this coordinate space, so the offset places the Compose
        // view exactly over the reported area. The stack and the overlay stay inside the safe
        // area: where a view ignores it, SwiftUI hands the window insets to the hosted Compose
        // view, and Compose would pad them a second time.
        .coordinateSpace(.named(ComposeFrameReader.space))
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }

    /// Reads the selected tab from Kotlin and sends taps to Kotlin. A tap on the open tab also
    /// goes to Kotlin, which returns that tab to its root.
    private func tabSelection(_ state: TabShellState) -> Binding<Int> {
        Binding(
            get: { Int(state.selected) },
            set: { KmpHelper.shared.selectShellTab(index: Int32($0)) }
        )
    }
}

/// An empty view that reports its safe content area in the coordinates of the shell stack. Inside a tab, that is
/// the area left by the tab bar or the sidebar. The keyboard is not part of it, because Compose
/// moves the focused field above the keyboard itself.
private struct ComposeFrameReader: View {
    static let space = "shell"

    @Binding var frame: CGRect
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Color.clear
            .onGeometryChange(for: CGRect.self) { proxy in
                safeFrame(proxy.frame(in: .named(Self.space)), proxy.safeAreaInsets)
            } action: { frame = $0 }
            .ignoresSafeArea(.keyboard)
    }

    /// The frame without the insets that are still in it, in case the parent ignores the safe area.
    /// Rounded to whole points, so subpixel layout noise does not resize Compose.
    private func safeFrame(_ frame: CGRect, _ insets: EdgeInsets) -> CGRect {
        let left = layoutDirection == .leftToRight ? insets.leading : insets.trailing
        let right = layoutDirection == .leftToRight ? insets.trailing : insets.leading
        return CGRect(
            x: (frame.minX + left).rounded(),
            y: (frame.minY + insets.top).rounded(),
            width: max(0, frame.width - left - right).rounded(),
            height: max(0, frame.height - insets.top - insets.bottom).rounded()
        )
    }
}

/// The tab state that Kotlin publishes (`KmpHelper.observeTabShell`), for SwiftUI.
@MainActor
private final class TabShellModel: ObservableObject {
    @Published private(set) var state: TabShellState?
    private var subscription: ComposeApp.Cancellable?

    init() {
        subscription = KmpHelper.shared.observeTabShell { [weak self] state in
            self?.state = state
        }
    }

    deinit {
        subscription?.cancel()
    }
}

/// Reports the fold of iPhone Duo to Kotlin (`FoldStateSource`, read as `LocalFoldState`).
///
/// The reserved-region and hinge APIs are in the iOS 27.1 SDK. Build with the Swift flag
/// `IPHONE_DUO_SDK` (Active Compilation Conditions) to compile them; without it, as on the
/// iOS 26 SDK of CI, this does nothing, and Compose sees a flat display. On the 27.1 SDK the
/// calls still check `#available`, so the app runs on older iOS versions.
enum FoldStateBridge {
    static func attach(to host: UIView) {
        #if IPHONE_DUO_SDK
        if #available(iOS 27.1, *) {
            let tracker = DivisionTrackingView()
            tracker.translatesAutoresizingMaskIntoConstraints = false
            tracker.isUserInteractionEnabled = false
            host.addSubview(tracker)
            NSLayoutConstraint.activate([
                tracker.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                tracker.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                tracker.topAnchor.constraint(equalTo: host.topAnchor),
                tracker.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
            tracker.setNeedsUpdateConstraints()

            host.addInteraction(UIHingeInteraction { _, update in
                KmpHelper.shared.reportHinge(status: update.hinge.map { hingeStatus($0.status) })
            })
        }
        #endif
    }

    #if IPHONE_DUO_SDK
    @available(iOS 27.1, *)
    private static func hingeStatus(_ status: UIHinge.Status) -> HingeStatus {
        switch status {
        case .closed: return .closed
        case .partiallyOpen: return .partiallyOpen
        case .fullyOpen: return .fullyOpen
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
    #endif
}

#if IPHONE_DUO_SDK
/// A transparent view over the whole Compose host view, so its coordinates are the Compose window
/// coordinates (1 pt = 1 dp). UIKit runs `updateConstraints()` again whenever a reserved region
/// that it read changes, so this reports every fold and unfold.
@available(iOS 27.1, *)
private final class DivisionTrackingView: UIView {
    override class var requiresConstraintBasedLayout: Bool { true }

    override func updateConstraints() {
        // Inactive regions are read too, so UIKit also calls again when the fold becomes active.
        let division = reservedRegions(kind: .division, options: .includeInactive).first { $0.isActive }
        if let frame = division?.frame {
            KmpHelper.shared.reportFoldDivision(
                left: Double(frame.minX),
                top: Double(frame.minY),
                width: Double(frame.width),
                height: Double(frame.height)
            )
        } else {
            KmpHelper.shared.clearFoldDivision()
        }
        super.updateConstraints()
    }
}
#endif

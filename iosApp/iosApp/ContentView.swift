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
    @ObservedObject private var player = PlayerModel.shared
    /// The safe area of the window, in window coordinates. The shell stack fills it.
    @State private var safeAreaFrame: CGRect = .zero
    /// The area of the open tab that is free of the tab bar, in window coordinates.
    @State private var tabArea: CGRect = .zero
    /// The visible tab bar in window coordinates, or nil while none shows.
    @State private var tabBar: CGRect?
    /// The fold of iPhone Duo in the coordinates of the shell stack.
    @State private var fold: FoldDivision?
    /// A tab that only Swift selected (Settings), shown instead of Kotlin's selected tab.
    @State private var localSelection: Int?
    /// The Compose settings screen was asked for (More Settings), instead of the native one.
    @State private var composeSettingsRequested = false

    /// Where the Compose view goes, in the coordinates of the shell stack: the free area of the
    /// open tab, or the whole safe area while no tab bar shows (the settings screen, and the
    /// expanded player, which covers the screen as a full-screen player does).
    private var composeFrame: CGRect {
        guard showsTabs else { return safeArea }
        let area = tabAreaInShell
        guard let mini = miniPlayerFrame else { return area }
        // Leave the bottom of the tab area to the native mini player.
        return CGRect(x: area.minX, y: area.minY, width: area.width, height: max(0, mini.minY - area.minY - 6))
    }

    /// The tabs that SwiftUI draws natively. The others show the Compose screen.
    private static let nativeTabs: Set<String> = ["home", "library", "search", "settings"]
    /// Tabs that only Swift selects: Kotlin's Settings item would leave the tabs for the
    /// top-level settings screen.
    private static let localTabs: Set<String> = ["settings"]

    private func selectedIndex(_ state: TabShellState) -> Int {
        localSelection ?? Int(state.selected)
    }

    private var showsNativeTab: Bool {
        guard let state = shell.state, state.active else { return false }
        let index = selectedIndex(state)
        return index < state.tabs.count && Self.nativeTabs.contains(state.tabs[index].key)
    }

    /// The native settings screen in place of the Compose one before the tabs (not connected or
    /// not signed in).
    private var showsNativeSettings: Bool {
        !(shell.state?.active ?? false) && shell.settingsShowing && !composeSettingsRequested
    }

    private var hidesCompose: Bool { showsNativeTab || showsNativeSettings }

    /// Opens the Compose settings screen, through Kotlin's Settings item.
    private func openComposeSettings() {
        guard let state = shell.state, let index = state.tabs.firstIndex(where: { $0.key == "settings" }) else { return }
        composeSettingsRequested = true
        localSelection = nil
        KmpHelper.shared.selectShellTab(index: Int32(index))
    }

    /// Room that native screens leave at the bottom for the mini player.
    private var miniPlayerInset: CGFloat {
        guard let mini = miniPlayerFrame else { return 0 }
        return max(0, tabAreaInShell.maxY - mini.minY) + 8
    }

    @ViewBuilder
    private func nativeTab(_ key: String) -> some View {
        switch key {
        case "home": HomeView(bottomInset: miniPlayerInset)
        case "library": LibraryView(bottomInset: miniPlayerInset)
        case "search": SearchView(bottomInset: miniPlayerInset)
        case "settings": SettingsView(isTopLevel: false, bottomInset: miniPlayerInset, openMoreSettings: openComposeSettings)
        default: EmptyView()
        }
    }

    private var showsTabs: Bool {
        (shell.state.map { $0.active && !$0.playerExpanded } ?? false) && !tabArea.isEmpty
    }

    /// The safe area in the coordinates of the shell stack.
    private var safeArea: CGRect {
        CGRect(origin: .zero, size: safeAreaFrame.size)
    }

    private var tabAreaInShell: CGRect {
        tabArea.offsetBy(dx: -safeAreaFrame.minX, dy: -safeAreaFrame.minY)
    }

    /// The glass mini player at the bottom of the tab area, in the coordinates of the shell
    /// stack, while a player is available.
    private var miniPlayerFrame: CGRect? {
        guard showsTabs, player.current != nil else { return nil }
        let area = tabAreaInShell
        let margin: CGFloat = 12
        let height: CGFloat = 60
        // Beside a vertical tab bar (iPhone Duo), the bottoms of the two line up. Above a bottom
        // tab bar, or with no bar, the player sits a margin above the free area's bottom.
        let bottom = tabBar.flatMap { bar in
            bar.height > bar.width ? min(bar.maxY - safeAreaFrame.minY, safeArea.maxY) : nil
        } ?? area.maxY - 8
        var minX = area.minX + margin
        // In book posture the player stays on the side of the fold next to the tab bar.
        if let fold, fold.posture == .book, fold.frame.maxX > area.minX, fold.frame.minX < area.maxX {
            minX = max(minX, fold.frame.maxX + foldGutter)
        }
        return CGRect(x: minX, y: bottom - height, width: max(0, area.maxX - margin - minX), height: height)
    }


    var body: some View {
        ZStack(alignment: .topLeading) {
            if let state = shell.state, state.active {
                TabView(selection: tabSelection(state)) {
                    ForEach(Array(state.tabs.enumerated()), id: \.offset) { index, tab in
                        Tab(tab.title, systemImage: tab.symbol, value: index) {
                            Group {
                                if Self.nativeTabs.contains(tab.key) {
                                    nativeTab(tab.key)
                                        .background(TabAreaProbe(area: $tabArea, bar: $tabBar))
                                } else {
                                    TabAreaProbe(area: $tabArea, bar: $tabBar)
                                }
                            }
                                // The expanded player covers the content, as in Compose.
                                .toolbarVisibility(state.playerExpanded ? .hidden : .automatic, for: .tabBar)
                        }
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                // The tab bar and the sidebar lay out to the screen edges; the tab contents still
                // get the safe area.
                .ignoresSafeArea()
            } else if showsNativeSettings {
                SettingsView(isTopLevel: true)
            } else {
                Color.clear
            }
        }
        .background(ComposeFrameReader(frame: $safeAreaFrame))
        .readsFold(into: $fold)
        .onChange(of: shell.state?.active) { _, active in
            if active == true { composeSettingsRequested = false }
        }
        .onChange(of: shell.state?.selected) { _, _ in localSelection = nil }
        // An overlay, so the size of the Compose view never changes the layout that the readers
        // measure. As a sibling in the stack it fed back into the measured area, and on iPhone
        // Duo the two never settled.
        .overlay(alignment: .topLeading) {
            ComposeView()
                .ignoresSafeArea(.keyboard) // Compose has its own keyboard handling
                .frame(width: composeFrame.width, height: composeFrame.height)
                .clipped()
                .offset(x: composeFrame.minX, y: composeFrame.minY)
                // A native screen draws its own content; Compose stays composed underneath.
                .opacity(hidesCompose ? 0 : 1)
                .allowsHitTesting(!hidesCompose)
        }
        .overlay(alignment: .topLeading) {
            // In its own hosting controller, as a UIKit view like Compose: plain SwiftUI drawn
            // above the UIKit tab view does not get the touches, which the tab view takes.
            if let frame = miniPlayerFrame, let nowPlaying = player.current {
                HostedView(MiniPlayer(model: player, nowPlaying: nowPlaying))
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
            }
        }
        // A sheet on a narrow window; full screen on a wide one (the unfolded iPhone Duo), where a
        // sheet is a small card in the middle.
        .sheet(isPresented: nowPlayingPresented(fullScreen: false)) {
            NowPlayingView(model: player)
        }
        .fullScreenCover(isPresented: nowPlayingPresented(fullScreen: true)) {
            NowPlayingView(model: player, fullScreen: true)
        }
        // The stack and the overlay stay inside the safe area: where a view ignores it, SwiftUI
        // hands the window insets to the hosted Compose view, and Compose would pad them a
        // second time.
        .itemActionPresentations(isActive: !player.isNowPlayingPresented)
        .overlay(alignment: .top) { ConnectionBanner() }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }

    private var isWide: Bool { safeAreaFrame.width >= 600 }

    private func nowPlayingPresented(fullScreen: Bool) -> Binding<Bool> {
        Binding(
            get: { player.isNowPlayingPresented && isWide == fullScreen },
            set: { player.isNowPlayingPresented = $0 }
        )
    }

    /// Reads the selected tab from Kotlin and sends taps to Kotlin. A tap on the open tab also
    /// goes to Kotlin, which returns that tab to its root. Settings is selected in Swift only.
    private func tabSelection(_ state: TabShellState) -> Binding<Int> {
        Binding(
            get: { selectedIndex(state) },
            set: { index in
                let key = index < state.tabs.count ? state.tabs[index].key : ""
                if Self.localTabs.contains(key) {
                    localSelection = index
                } else {
                    localSelection = nil
                    KmpHelper.shared.selectShellTab(index: Int32(index))
                }
            }
        )
    }
}

/// An empty view that reports its frame in window coordinates, rounded to whole points so that
/// subpixel layout noise does not resize Compose.
private struct ComposeFrameReader: View {
    @Binding var frame: CGRect

    var body: some View {
        Color.clear
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global).roundedToPoints()
            } action: { frame = $0 }
            .ignoresSafeArea(.keyboard)
    }
}

/// Reports the area of the open tab that Compose can use, in window coordinates: the tab's
/// column inside the window's safe area, cut back to the edge of the visible tab bar.
///
/// It asks UIKit, because the safe area of the tab content is not reliable here. On the unfolded
/// iPhone Duo in portrait, the tab content reserves a band at the top while the tab bar floats
/// at the bottom, over the content.
private struct TabAreaProbe: UIViewControllerRepresentable {
    @Binding var area: CGRect
    @Binding var bar: CGRect?

    func makeUIViewController(context: Context) -> TabAreaProbeController {
        TabAreaProbeController()
    }

    func updateUIViewController(_ controller: TabAreaProbeController, context: Context) {
        controller.onChange = { area = $0; bar = $1 }
        controller.view.setNeedsLayout()
    }
}

final class TabAreaProbeController: UIViewController {
    var onChange: ((CGRect, CGRect?) -> Void)?
    private var reported: (area: CGRect, bar: CGRect?)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        report()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        report()
    }

    private func report() {
        guard let window = view.window else { return }
        let safe = window.bounds.inset(by: window.safeAreaInsets)
        var area = view.convert(view.bounds, to: window).intersection(safe)
        var barFrame: CGRect?
        if let bar = tabBarController?.tabBar, !bar.isHidden, bar.alpha > 0.01, bar.window != nil {
            let frame = bar.convert(bar.bounds, to: window).roundedToPoints()
            area = area.excluding(frame)
            barFrame = frame
        }
        area = area.roundedToPoints()
        guard reported.map({ $0.area != area || $0.bar != barFrame }) ?? true else { return }
        reported = (area, barFrame)
        // Not during the layout pass that SwiftUI may be running.
        DispatchQueue.main.async { [weak self] in self?.onChange?(area, barFrame) }
    }
}

private extension CGRect {
    func roundedToPoints() -> CGRect {
        CGRect(x: minX.rounded(), y: minY.rounded(), width: width.rounded(), height: height.rounded())
    }

    /// This rectangle cut back to the edge of a bar that overlaps it. A tall bar is at a side,
    /// as the vertical bar of iPhone Duo; a wide one is at the top or the bottom.
    func excluding(_ bar: CGRect) -> CGRect {
        guard intersects(bar), !isNull else { return self }
        var result = self
        switch (bar.height > bar.width, bar.midX > midX, bar.midY > midY) {
        case (true, true, _): result.size.width = max(0, bar.minX - minX)
        case (true, false, _): result = CGRect(x: bar.maxX, y: minY, width: max(0, maxX - bar.maxX), height: height)
        case (false, _, true): result.size.height = max(0, bar.minY - minY)
        case (false, _, false): result = CGRect(x: minX, y: bar.maxY, width: width, height: max(0, maxY - bar.maxY))
        }
        return result
    }
}

/// A SwiftUI view in its own hosting controller, embedded as a UIKit view.
private struct HostedView<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(_ content: Content) {
        self.content = content
    }

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: content)
        controller.view.backgroundColor = .clear
        controller.sizingOptions = []
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<Content>, context: Context) {
        controller.rootView = content
    }
}

/// The tab state that Kotlin publishes (`KmpHelper.observeTabShell`), for SwiftUI.
@MainActor
private final class TabShellModel: ObservableObject {
    @Published private(set) var state: TabShellState?
    /// The top-level settings screen is on (not connected, or not signed in).
    @Published private(set) var settingsShowing = false
    private var subscriptions: [ComposeApp.Cancellable] = []

    init() {
        subscriptions = [
            KmpHelper.shared.observeTabShell { [weak self] state in self?.state = state },
            KmpHelper.shared.observeSettingsShowing { [weak self] showing in self?.settingsShowing = showing.boolValue },
        ]
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
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

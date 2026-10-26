# iPhone Duo notes (researched 2026-10-26)

Sources:
- Prepare for iPhone Duo: https://developer.apple.com/iphone-duo/prepare/
- Tech Talk "Strike a pose with adaptive layouts on iPhone Duo": https://developer.apple.com/videos/play/tech-talks/111463/
- Tech Talk "Leverage multiple displays and scenes on iPhone Duo": https://developer.apple.com/videos/play/tech-talks/111464/
- SwiftUI onHingeChange: https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)

## SDK behaviour
- iOS 26 SDK builds: letterboxed/centered on the inner display.
- iOS 27 SDK: fills most of the inner display, avoids status bar on the right edge.
- iOS 27.1 SDK+: full display; system toolbars/tab bars lay out vertically below the status bar. App size changes on every fold/unfold mid-session.
- Don't size from UIScreen.main or orientation; size from the view/window and re-read on change (Compose: LocalWindowInfo.containerSize / currentWindowAdaptiveInfo).
- Each display has its own size class. Inner display in portrait ~669 pt wide (medium width class).

## Fold / hinge APIs (iOS 27.1)
- Hinge: SwiftUI `.onHingeChange { old, ctx in ctx.hinge?.status / .angle }`, UIKit `UIHingeInteraction`. Status: closed, partiallyOpen, fullyOpen; nil hinge = no hinge. Apple: use for effects/interactions, NOT layout.
- Layout: reserved regions. SwiftUI `GeometryProxy.reservedRegions(kind: .division | .occlusion, options: .includeInactive)`; UIKit `UIView.reservedRegions(kind:)`, `.frame`. Fold = division region, active only when partially folded (zero width when flat). FaceTime camera = occlusion region.
- Arrangements: SwiftUI `ArrangementView { primary } secondary: { }` + `.arrangementViewStyle(.split.axes(.horizontal))` / `.overlay`; UIKit `UIArrangementViewController`. Split for main/detail (player | up next).
- Design: tabletop (propped) -> top region for content viewed at distance (artwork), bottom region for controls. Book posture -> keep each element within one region, increase gutter at hinge, prefer even grid column counts when a division region exists. Scrolling lists don't displace.

## Compose Multiplatform mapping
- Window size: material3-adaptive `currentWindowAdaptiveInfo()` / WindowSizeClass (already used in WindowClass.kt); recomposes on resize.
- Fold state: no Compose API on iOS. Bridge from Swift (iosApp) by reading `reservedRegions(kind: .division, options: .includeInactive)` and `UIHingeInteraction` on the Compose host view and pushing into a Kotlin StateFlow (Kotlin/Native bindings may not have the 27.1 symbols yet; Swift side avoids that). Android: Jetpack WindowManager FoldingFeature.

# Music Assistant on iPhone Duo: native-feel plan (round 2, 2026-10-26)

poteto-mode: off. Quentin wants this done really well.

## What was captured (iPhone Duo sim, iOS 27.1, MacBook Air)
- `folded-settings-top.png`: outer display, first-run Settings screen.
- `folded-connect.png`: server connection form (Material text fields, tabs, pill button).
- `folded-auth-required.png`: connected to 100.69.19.74:8095 (MA 2.10.8). The server needs a username and password, so I stopped there. Library, album, now-playing and queue screens were not captured.
- `ref-settings-folded.png`: Apple Settings on the same display, for comparison. The sim runtime has no Apple Music app.
- **Not captured: unfolded, book or tabletop.** Xcode 27.1 handles poses in DeviceHub.app, and `simctl` has no pose command (`screenConfig power` only blanks a panel). Driving DeviceHub needs macOS Accessibility or Screen Recording permission for the remote shell on the Air, and that permission isn't granted. Quentin has to grant it, or someone clicks the pose in DeviceHub.
- Sim-only fix needed to run the app: an unsigned sim build crashes at launch in `INPreferences` because the Siri entitlement is missing, the same crash as on the device. Building with ad-hoc `CODE_SIGN_IDENTITY=-` and an entitlements file that has only `com.apple.developer.siri` works. No account or signing identity is used.

## Gaps seen in the screenshots (outer display)
1. **Content runs under the Duo's vertical control bar.** The status bar and clock pill sit on top of the Settings card and the WebRTC tab. Apple Settings stops its content left of that bar. Cause: ContentView.swift uses `.ignoresSafeArea(.container)`, and Compose only reads bottom navigation-bar insets. **Fix in Compose:** apply `WindowInsets.safeDrawing` (all sides, especially the trailing horizontal inset) at the scaffold root, and keep `ignoresSafeArea` only for full-bleed backgrounds and artwork. This is the single biggest "not native" signal and the cheapest to fix.
2. **Typography.** The title is regular-weight Roboto-style text, not the bold SF Pro large title. **Compose:** set the iOS typography to the system font (SF Pro via `FontFamily.Default` on iOS, or the platform font on iosMain) and use an HIG type scale: Large Title 34/bold, Headline 17/semibold, Body 17.
3. **Material 3 controls.** Filled text fields with an underline, a Material tab row with an indicator line, ALL-CAPS outlined "EXIT APP", a flat cyan pill, and Material checkboxes. Native equivalents: grouped inset form rows, a segmented `Picker`, plain or bordered-prominent buttons with Liquid Glass, and toggles instead of checkboxes. **Compose restyle on iOS** with an iOS-flavored component set. Alternatively, move Settings and Connect wholesale into a **SwiftUI `Form`**: it's a small, self-contained screen and gets native look and fold avoidance for free.
4. **Navigation chrome.** Compose draws its own `TwoRowTopAppBar` and `AdaptiveNavigationBarLayout`. On Duo, iOS 27.1 moves toolbars and the tab bar into the vertical side bar below the status bar, overflows into a menu when space runs out, and nudges controls out of the fold. Compose-drawn bars get none of that. **Needs native SwiftUI chrome:** a `TabView` with `.tabViewStyle(.sidebarAdaptable)` (a sidebar on the inner display, vertical side bar when folded), `NavigationStack` or `NavigationSplitView` toolbars, and SF Symbols tab icons. Compose content is hosted in each tab or column.
5. **Icons.** Material icons (the theme sun, moon and auto icons, the list icon next to Connect) read as Android. **Native:** SF Symbols in the SwiftUI chrome. Inside Compose, swap to SF Symbol exports or an SF-style icon set on iOS.
6. **Colors and materials.** The flat light-grey cards and cyan accent don't follow the system. **Native:** system grouped backgrounds (`systemGroupedBackground`), Liquid Glass (`.glassEffect`) on floating controls and the mini player, and the system accent. You can approximate this in Compose with colors, but real glass needs SwiftUI layers.
7. **Sheets.** The Compose `ModalBottomSheet` won't adopt the Duo sheet behavior: vertical controls on the outer display, sliding away from the fold. **Native:** present queue, player options and similar-artists as SwiftUI `.sheet`s hosting Compose, or at least keep them inside the system safe area and the regions from item 8.
8. **Hinge and pose (from research, not yet verified in the sim).** Book pose: keep each element within one region, use an even column count when there's a division region, add a gutter at the fold. Tabletop: artwork on top, controls on the bottom. Flat: two columns (artwork | controls, or list | detail). The branch already reads `reservedRegions(.division)` in ContentView.swift. Make that drive layout through a Kotlin StateFlow, and use SwiftUI `ArrangementView` with `.arrangementViewStyle(.split)` for player | up-next.

## How Apple's own apps lay it out
- Music: the stacked layout becomes two columns when there's horizontal room (artwork | controls or lyrics). Tabletop puts the art above the fold and controls below.
- Health: tab bar shown as a sidebar on the inner display. That suits information-dense apps; MA's Library qualifies.
- Every app keeps the same hierarchy inside and out, with no features tied to one pose.

## Recommendation: a hybrid with a SwiftUI shell and restyled Compose content
- **Move to SwiftUI** (where the Duo system behaviors live, so Compose can't imitate them convincingly):
  - The root `TabView(.sidebarAdaptable)`: Home, Library, Search, Players.
  - Navigation titles and toolbars.
  - Sheets.
  - The now-playing and mini-player glass chrome.
  - Settings and Connect as a `Form`.
  - The fold-aware player using `ArrangementView` or `onGeometryChange` with `reservedRegions`.
- **Keep in Compose, restyled for iOS:**
  - Grids, lists, album and artist detail bodies, the queue list.
  - These take an iOS theme: SF font, HIG type scale, system colors, safe-area insets, iOS list rows, no Material ripple.
- **Order:**
  1. Insets fix plus iOS typography and colors (a day; biggest visible win).
  2. A SwiftUI tab and sidebar shell hosting the existing Compose screens per tab (needs a small Kotlin navigation API, so the shell can drive tab selection and push destinations).
  3. A native Settings form.
  4. Native sheets and a fold-aware now playing.
- Expected result: it feels like a Swift app in the chrome, which is what people see and touch first, while most of the shared code stays.
- Cost: the iOS UI diverges from Android, and that is less attractive to upstream. Keep it behind an iOS-only shell so the shared Compose code stays upstreamable.

## Before the next round
- Grant Accessibility (or Screen Recording) to the remote-exec agent on the Air so DeviceHub poses can be scripted, or switch the poses by hand.
- Provide a Music Assistant login for the sim (Quentin types it), or a test user, to reach the library, album, player and queue screens.

## Sources
- https://developer.apple.com/iphone-duo/prepare/
- https://developer.apple.com/videos/play/tech-talks/111466/ (Design for iPhone Duo: vertical control bar, sidebar tab bar, sheet behavior, fold avoidance)
- https://developer.apple.com/videos/play/tech-talks/111463/ (Strike a pose: reservedRegions, ArrangementView)
- https://developer.apple.com/videos/play/tech-talks/111464/ (multiple displays and scenes)
- https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)
- https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo (mirror with change log: https://appguidelines.com/human-interface-guidelines/version/22/designing-for-iphone-duo/)
- How Music-style apps lay out on Duo: https://marquee.fm/features/iphone-duo/ and https://routenote.com/radar/music-streaming-on-iphone-duo-what-does-apples-foldable-change/

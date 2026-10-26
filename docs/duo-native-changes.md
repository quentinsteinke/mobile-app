# iPhone Duo native feel: changes in phase 1 and 2 (branch `duo-native`)

This branch does phases 1 and 2 of [duo-native-plan.md](duo-native-plan.md): the safe-area fix,
an iOS theme for Compose, and a SwiftUI tab shell. Android keeps its current look and behaviour:
the branch changes no `androidMain` or `androidApp` file, and each shared hook falls back to the
Material path when nothing provides it.

## What changed

### 1. Safe areas
- `ContentView.swift` no longer applies `.ignoresSafeArea(.container)` to the Compose view.
  Compose stays inside the safe area, and only the system background fills the screen edges.
- Compose on iOS reports the insets of the whole window, wherever its view is
  (`WindowInsetsManager` reads the window's root view too). `IosAppRoot` (`iosMain`) therefore
  pads UIKit's `safeAreaInsets` of the Compose view, which counts only the unsafe area that the
  view overlaps, and consumes the window insets, so no screen below pads them again. The
  keyboard inset stays with Compose.
- The Compose view clips to its frame. Compose moves its content up above the keyboard, and that
  content went under the status bar.

### 2. iOS theme (`iosMain/.../ui/theme/`)
- `LocalPlatformStyle` (`commonMain/.../ui/theme/PlatformStyle.kt`) is the shared hook. Only iOS
  provides it (`IosPlatformStyle`, from `MainViewController`).
- Colors (`IosColorScheme.kt`): the Material roles are mapped to UIKit system colors, resolved
  for light or dark and for the contrast setting: `systemBackground`, `label`, `secondaryLabel`,
  `systemGray5`/`systemGray6` containers, separators, and `systemBlue` as the accent. There is
  no tonal elevation tint.
- Type (`IosTypography.kt`): `FontFamily.Default` (SF Pro) in the HIG text styles, with Apple's
  tracking. Large Title 34 bold, Title 1 to 3, Headline 17 semibold, Body 17, Callout,
  Subheadline, Footnote, Caption. The top app bar title (`titleLarge`) uses Title 3.
- No ripple: `LocalRippleConfiguration` is null, and `LocalIndication` is an iOS-style highlight
  (`IosHighlightIndication`) that dims on press and fades out on release.
- Text fields: the filled fields of the connection, login and search screens take
  `platformStyled()` colors and `platformTextFieldShape()`. On iOS that gives a rounded
  10 pt field with the system fill and no indicator line. The outlined fields in dialogs and the
  Sendspin section keep the Material component, with iOS colors and radii.
- No all-caps buttons: the "EXIT APP" button is hidden on iOS (`showsExitButton = false`),
  because iOS apps must not quit themselves, and `platformButtonLabel` shows "BROWSE LIBRARY" as
  "Browse library". Android keeps both as they are.
- SF Symbols: the shared screens use `ui/compose/common/Icon`, a drop-in for the Material
  `Icon`. On iOS it draws an SF Symbol for each vector in the table in `SfSymbols.kt`: Material,
  the app's custom player icons, Tabler, and FontAwesome (the appearance choice in Settings).
  Every symbol name was checked against the SF Symbols catalogue. An unmapped vector, or one
  drawn through a `painterResource`, still draws its own glyph.

### 3. SwiftUI tab shell (`iosApp/iosApp/ContentView.swift`)
- `ContentView` is a `TabView` with `.tabViewStyle(.sidebarAdaptable)`, laid out by the system.
  The tabs are Home, Library, Search and Settings, with SF Symbols and the localized Compose
  titles.
- One Compose view sits in an overlay above the `TabView`, over the free area of the open tab.
  Compose renders that tab. There is not a Compose view per tab, and the view does not move
  between tabs: either would stop and restart the Compose lifecycle on each tab switch, and the
  app disconnects from the server when the lifecycle stops.
- The free area comes from UIKit (`TabAreaProbe`): the tab's column inside the window safe area,
  cut back to the frame of the visible tab bar, whether the bar is vertical, at the bottom or at
  the top. SwiftUI's safe area of the tab content is not used, because on the unfolded Duo in
  portrait it reserves a band at the top while the tab bar floats at the bottom.
- The Compose view is an overlay, so its size never feeds back into the layout that is measured.
  As a sibling it caused a layout loop on the Duo, and Compose was never drawn.
- Kotlin keeps the tab state. `MainNavigationRoot` publishes its tabs to `LocalNativeTabShell`
  (`IosTabShell`) and draws no navigation bar or rail of its own while the shell exists. Swift
  reads `KmpHelper.observeTabShell` and sends taps to `KmpHelper.selectShellTab`. Back stacks,
  "back to Home", deep links and the jump to Search from a library list are unchanged. The shell
  shows tabs only while the main screen is on. The connection and settings screen fills the safe
  area.
- While the full player is expanded, the tab bar is hidden and the player fills the safe area.
- The fold bridge (`FoldStateBridge`) is unchanged and still behind `#if IPHONE_DUO_SDK`. It
  reports the division in Compose-view coordinates.

## Verification
- On Linux: `./gradlew detektAll testAndroidHostTest` passes (962 tests, 0 failures).
  `:composeApp:compileKotlinIosArm64` compiles.
- On the Mac Mini: an unsigned build for a generic iOS device against the iOS 27.1 SDK, with
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG IPHONE_DUO_SDK`, succeeds. The iPhone 18 Pro
  simulator runs the app. The Mini's iPhone Duo simulators never finish booting (also a new one),
  so the Duo was tested on the MacBook Air.
- On the MacBook Air, iPhone Duo simulator (iOS 27.1), driven with Peekaboo and logged in to the
  2.10.8 server:
  - Folded, unfolded in landscape and in portrait, and book (partially open): nothing under the
    status bar, the vertical status bar or the home indicator, and the Compose content meets the
    tab bar.
  - The tab bar: vertical at the trailing edge when folded and in unfolded landscape, a floating
    bar at the bottom in unfolded portrait. Tab taps switch the Compose tab.
  - Library on the wide display: the categories beside the open category (two panes).
  - Expanded player: the tab bar hides and the player fills the safe area. In book pose the
    player splits at the fold, so the fold state reaches Compose.
  - Dark mode, the SF Symbols (tabs, top bars, player controls, menus, theme choice), SF Pro, and
    the sentence-case "Browse library".
- Bugs found and fixed in that test: the layout loop (blank screen on the Duo), the double
  safe-area padding (Compose window insets, and insets subtracted twice in the shell), the tab bar
  hidden under Compose in portrait, and the all-caps "BROWSE LIBRARY".

## Check on a device (iPhone Duo, iOS 27.1)
1. Unfolded, the system shows a tab bar, not a sidebar (vertical in landscape, at the bottom in
   portrait), although the size class is regular. Decide whether to force the sidebar.
2. Keyboard: the simulator used the hardware keyboard, so the clip fix for the on-screen keyboard
   is not verified. On the connection and login fields, the focused field must move above the
   keyboard without content going under the status bar.
3. Tabletop pose: not tested.
4. A tap on the open tab returns it to its root only if SwiftUI calls the binding setter for the
   selected tab. Not tested.
5. Sheets and dialogs (similar artists, lyrics, DSP settings) are Compose: they are not the native
   Duo sheets. Phase 4 is meant to replace them.
6. Press feedback: rows and cards dim on press. Material buttons and icon buttons give no press
   feedback, because their ripple is off and they do not use `LocalIndication`.
7. Large Dynamic Type sizes, Increase Contrast and Bold Text.
8. CarPlay and Siri. The shell does not touch them, but they share the app process.

## Not done in this round
- Content does not scroll under the glass tab bar: Compose stops at the bar's edge, and on the
  folded Duo the strip below the content (the home indicator inset) stays empty. Scrolling under
  the bars needs the bar insets as content padding in each scrolling screen.
- Remaining Material controls: switches (the DSP switch is hard to see), checkboxes ("Use TLS",
  "Allow landscape"), and the tab rows (Direct/WebRTC, the authentication methods). The plan's
  native Settings form replaces most of them.
- The spiral holes on playlist tiles are drawn in the primary color, so on iOS they are system
  blue.
- Native toolbars. Each Compose screen draws its own top bar, with actions, menus, a search
  field and a second row of chips. A native `NavigationStack` toolbar needs a per-screen API to
  publish the title and the actions to Swift.
- The Search tab does not use `Tab(role: .search)` or `.searchable`. The Compose search screen
  owns the field.
- The plan's later phases: the native Settings form, native sheets, the glass mini player, and
  the fold-aware now-playing (`ArrangementView`).

# iPhone Duo native feel: changes in phase 1 and 2 (branch `duo-native`)

This branch does phases 1 and 2 of [duo-native-plan.md](duo-native-plan.md): the safe-area fix,
an iOS theme for Compose, and a SwiftUI tab shell. Android keeps its current look and behaviour:
the branch changes no `androidMain` or `androidApp` file, and each shared hook falls back to the
Material path when nothing provides it.

## What changed

### 1. Safe areas
- `ContentView.swift` no longer applies `.ignoresSafeArea(.container)` to the Compose view, so
  Compose stays inside the safe area. Only the system background fills the screen edges.
- `IosAppRoot` (`iosMain`) pads and consumes every side of the safe area (`systemBars` and
  `displayCutout`) around `App()`. This covers the trailing vertical status bar of the Duo even
  on a screen that reads only the top inset. The keyboard inset stays with Compose.

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
- No all-caps button: the "EXIT APP" button is hidden on iOS (`showsExitButton = false`),
  because iOS apps must not quit themselves. Android still shows it.
- SF Symbols: the shared screens use `ui/compose/common/Icon`, a drop-in for the Material
  `Icon`. On iOS it draws an SF Symbol for each vector in the table in `SfSymbols.kt`: Material,
  the app's custom player icons, Tabler, and FontAwesome (the appearance choice in Settings).
  Every symbol name was checked against the SF Symbols catalogue. An unmapped vector, or one
  drawn through a `painterResource`, still draws its own glyph.

### 3. SwiftUI tab shell
- `ContentView` is a `TabView` with `.tabViewStyle(.sidebarAdaptable)`. The system lays it out:
  a sidebar on the wide inner display, a tab bar on a narrow display, and (iOS 27.1 SDK) the
  vertical bar below the status bar on the folded Duo. The tabs are Home, Library, Search and
  Settings, with SF Symbols and the localized Compose titles.
- How Compose is hosted: one Compose view sits above the `TabView`, sized to the content area
  of the open tab (`ComposeFrameReader`). Compose renders that tab. There is not a separate
  Compose view per tab, and the view does not move between tabs. Either of those would stop and
  restart the Compose lifecycle on each tab switch, and the app disconnects from the server when
  the lifecycle stops.
- Kotlin keeps the tab state. `MainNavigationRoot` publishes its tabs to `LocalNativeTabShell`
  (`IosTabShell`) and draws no navigation bar or rail of its own while the shell exists. Swift
  reads `KmpHelper.observeTabShell` and sends taps to `KmpHelper.selectShellTab`. Back stacks,
  "back to Home", deep links and the jump to Search from a library list are unchanged. The shell
  shows tabs only while the main screen is on. The connection and settings screen fills the
  window.
- The tab bar is hidden while the full player is expanded.
- The fold bridge (`FoldStateBridge`) is unchanged and still behind `#if IPHONE_DUO_SDK`. It
  reports the division in Compose-view coordinates, so it stays correct when the view is beside
  a sidebar.

## Verification
- On Linux: `./gradlew detektAll testAndroidHostTest` passes (962 tests, 0 failures).
  `:composeApp:compileKotlinIosArm64` and `:composeApp:compileAndroidMain` compile.
- On the Mac Mini (Xcode 27.1, iOS 27.1 SDK): an unsigned Debug build for a generic iOS device,
  with `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG IPHONE_DUO_SDK`, succeeds. That covers the
  Kotlin framework link, the Swift shell, and the Duo-only Swift. No touched file gives a warning.
- Not run: no simulator or device run. The UI has not been looked at yet.

## Check on a device (iPhone Duo, iOS 27.1)
1. Folded, unfolded, book and tabletop: no content under the status bar, the vertical control
   bar, the home indicator or the camera. The Compose content meets the tab bar or the sidebar
   with no gap and no overlap.
2. Unfolded: the tabs show as a sidebar. Folded: as a tab bar, vertical below the status bar.
   Folding or unfolding resizes the Compose content to the new area.
3. Tab taps switch tabs. A tap on the open tab returns it to its root (this depends on SwiftUI
   calling the binding setter for the selected tab). Settings opens the settings screen, and
   "home" from there brings the tabs back.
4. Expanded player: the tab bar hides. Check whether the sidebar hides too in the unfolded pose.
5. Bottom sheets and dialogs (queue, player options, similar artists, lyrics) cover only the
   content area, not the tab bar or the sidebar, and the tabs stay tappable under them. Phase 4
   (native sheets) is meant to fix this.
6. The cold-launch splash during auto-login shows inside the content area with the tabs around
   it. Check that this looks acceptable.
7. Light, dark and "follow system", also switched in Settings at runtime: the colors match the
   system background at the screen edges. Increase Contrast and Bold Text apply.
8. SF Pro and the type scale look right at the default and at large Dynamic Type sizes.
9. Press feedback: rows and cards dim on press. Material buttons and icon buttons now give no
   press feedback, because their ripple is off and they do not use `LocalIndication`.
10. SF Symbols: the glyph size and weight next to text, the tint of selected and disabled
    states, and that shuffle and repeat show "on" as a filled circle.
11. Keyboard: on the connection and login fields, the focused field moves above the keyboard,
    and the shell does not jump.
12. Compose gets zero safe-area insets inside the shell. If SwiftUI passes insets to the hosted
    view, the content gets a double margin at that edge.
13. CarPlay and Siri still work. The shell does not touch them, but they share the app process.

## Not done in this round
- Native toolbars. Each Compose screen draws its own top bar, with actions, menus, a search
  field and a second row of chips. A native `NavigationStack` toolbar needs a per-screen API to
  publish the title and the actions to Swift, or a duplicated Compose bar has to be hidden.
  That fits with phase 3 of the plan (the native Settings form) and later work.
- The Search tab does not use `Tab(role: .search)` or `.searchable`. The Compose search screen
  owns the field.
- The plan's later phases: the native Settings form, native sheets, the glass mini player, and
  the fold-aware now-playing (`ArrangementView`).

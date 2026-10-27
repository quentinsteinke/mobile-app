# Native SwiftUI port for iOS and iPhone Duo (branch `ios-native`)

The iOS app draws its main screens in SwiftUI. The Kotlin core stays as it is: the view models,
the repositories, the player and the network code. Android does not change.

## How it fits together

- **SKIE** (`co.touchlab.skie`) exports the Kotlin API to Swift. A `StateFlow` is an async
  sequence with `.value`, and a Kotlin enum is a Swift enum.
- **Bridges** in `composeApp/src/iosMain/kotlin/io/music_assistant/client/nativeui/` wrap the
  existing view models for Swift. A `NativeScreen` owns a `ViewModelStore` and a scope.
  `close()` clears both, the same as leaving a Compose navigation entry. The bridges map the
  Kotlin models to flat data classes (`NativeMediaItem`, `NativeNowPlaying`) and send actions
  back to the view models. The gates, such as scopes, server schema and feature support, are
  the Compose gates.
- **SwiftUI** in `iosApp/iosApp/Native/` holds one model per screen. A model follows its bridge's
  state flow and closes the bridge when the view goes away.
- **The shell** (`iosApp/iosApp/ContentView.swift`) is a `TabView` with `.sidebarAdaptable`. Kotlin
  still owns the tab state through `IosTabShell`, so deep links and "tap the open tab to go back
  to its root" keep working. The Compose view stays composed under the native tabs, hidden, so
  the Compose lifecycle and the server session do not restart on a tab switch.

## Hooks in the shared code

Each hook is optional. Android provides none, so Android behaves as before.

| Hook | Where | What iOS does with it |
|------|-------|-----------------------|
| `LocalNativeTabShell` (`drawsPlayer`, `Publish`, `expandPlayer`, `openLibraryList`) | `ui/compose/nav/NativeTabShell.kt` | Native tabs, player and the player and library deep links |
| `LocalNativeSettingsHost` | `ui/compose/nav/NativeSettingsHost.kt` | Native settings and connection screen |
| `LocalNativeMessageSink` | `ui/compose/nav/NativeMessageSink.kt` | Server errors as a native toast |
| `LocalPlatformStyle` | `ui/theme/PlatformStyle.kt` | iOS look for the Compose screens that remain |

## Features

- **Home**: the recommendation rows, refresh, and Edit Rows (order, show or hide).
- **Search**: results by type, one type or all types, and Library Only.
- **Library**: the categories (a sidebar on a regular-width window), with an editor for their
  order and visibility. Every library list has search, sort, Favorites Only, grid or list, and
  paging. Playlists can be created, and audiobooks can group their series.
- **Browse** and **AI Radio**.
- **Detail pages**: album, playlist, podcast, audiobook (with chapters), genre (with its
  artists), and artist (songs, albums, similar artists, See All). Playlists can refresh, and a
  row can be removed from an editable playlist.
- **Long-press menus**: the same entries as Compose. That is the five queue options, play from
  here, shuffled, from beginning, endless mix, library, favorite and dislike, add to playlist (a
  native chooser that can also create one), and mark played.
- **Player**: the glass mini player and Now Playing. Now Playing has the scrubber, transport,
  volume, favorite, the player choice, and the queue (play, remove, move, clear). Its More menu
  holds lyrics (synced, tap a line to seek), sleep timer, speed, autoplay, crossfade, Go to
  Album and Artist, start radio, the item menu, stream details, DSP, announcements (type, or
  hold to talk on a remote player), ambient sound and the AI Radio DJ. Group Speakers sets the
  group members and their volumes.
- **Settings**: connection (direct and remote ID), sign-in (password and Home Assistant), the
  server, theme, landscape, the local player, logs and crash logs. **More Settings** opens the
  Compose settings for the rest. That is the car options, the client certificate, the custom
  Sendspin server, the default click actions and the QR scan.
- **App-wide**: action and error toasts, the reconnect banner, and the deep links.
- **Strings**: `L(key, english)` reads the app strings (`NativeText`), so a label with a key is
  translated. About 60 labels use it. The others are English until they get a key.

## iPhone Duo postures

`readsFold(into:)` (`Native/Fold.swift`) reads the reserved division region in the view's own
coordinates, so it also works in a presented screen. It needs the iOS 27.1 SDK and the Swift flag
`IPHONE_DUO_SDK`. Without them the display is flat. `FoldSplit` lays two parts out around the fold.

| Posture | Layout |
|---------|--------|
| Folded (outer display) | Phone layouts. The vertical status bar, toolbar and tab bar sit on the right. |
| Open, landscape | Library sidebar, album header beside the list, Now Playing full screen with the artwork beside the controls, Settings at a readable width. |
| Open, portrait | The same, with the floating bottom tab bar. |
| Book (half open, vertical fold) | Album page, Now Playing and Settings split at the fold. The Library sidebar ends at the fold, and the open category starts past it. The mini player stays on the tab-bar side. |
| Tabletop (half open, horizontal fold) | Now Playing has the artwork above the fold and the controls below. The album page puts its header above and the list below. |

## Build and test

- Simulator: the iPhone Duo simulator on the MacBook Air (iOS 27.1, DeviceHub). Build with
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG IPHONE_DUO_SDK'`.
- Device: a Debug build signed with team `8C5LBVCRXP`, with the Siri entitlement only. CarPlay
  needs an entitlement that Apple grants separately, so it is not in this build.
- Shared checks: `./gradlew detektAll testAndroidHostTest`.

## Known gaps

- Deep links compile but were not exercised on the simulator, because the original Music
  Assistant app is installed there too and takes the `musicassistant://` scheme.
- Voice announcements (hold to talk) and the reconnect banner have not been tried on the
  device.
- The settings under More Settings are still Compose.
- About 100 native labels have no string key yet, so they are English only.
- Horizontal rows scroll under the vertical bars of the folded and the open display, as glass
  content does elsewhere in iOS.

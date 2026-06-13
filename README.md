# CleanLock

CleanLock is a small native macOS utility for cleaning your MacBook keyboard and trackpad without accidental input.

It lives in the menu bar, dims the screen, temporarily blocks keyboard and pointer input, and gives you a clear way back: hold the left and right Command keys for 3 seconds.

## Features

- Blocks keyboard input while cleaning.
- Blocks clicks, taps, drags, mouse movement, and scroll events while cleaning.
- Shows a dark full-screen overlay so dust, fingerprints, and smudges are easier to see.
- Unlocks with `Left Command` + `Right Command` held for 3 seconds.
- Shows visual Command-key indicators and progress rings during unlock.
- Supports an automatic safety timeout: 5, 10, or 20 minutes.
- Can dim all displays or only the main display.
- Runs as a menu bar app without staying in the Dock after onboarding.
- Optional launch at login via the native macOS Login Items API.
- Works locally on your Mac. No network, no analytics, no key logging.

## Why

Cleaning a MacBook keyboard or trackpad usually means either shutting the Mac down or fighting accidental key presses, clicks, app switches, and random shortcuts.

CleanLock gives you a quick temporary cleaning mode: turn it on from the menu bar, wipe the keyboard/trackpad/screen, then unlock with both Command keys.

## Privacy

CleanLock does not record keystrokes.

CleanLock does not use the internet.

CleanLock does not collect analytics.

CleanLock does not send data anywhere.

The app needs input-related permissions only to block input during cleaning mode and to detect the unlock gesture.

## Required Permissions

macOS requires explicit permission for apps that monitor or intercept input. CleanLock asks for:

- Accessibility: used to temporarily block keyboard and pointer events.
- Input Monitoring: used to detect the left and right Command keys for unlocking.

You can review or revoke these permissions anytime in System Settings:

`Privacy & Security` -> `Accessibility`

`Privacy & Security` -> `Input Monitoring`

## How To Use

1. Launch CleanLock.
2. Complete onboarding.
3. Grant the required macOS permissions.
4. Pass the unlock test by holding left and right Command.
5. Click the CleanLock icon in the menu bar.
6. Choose `Включить режим очистки`.
7. Clean your keyboard, trackpad, and screen.
8. Hold left and right Command for 3 seconds to exit cleaning mode.

If the unlock gesture does not work, CleanLock exits automatically after the configured safety timeout.

## External Keyboards

CleanLock uses the left and right Command keys as the unlock gesture.

Some external keyboards do not have a right Command key, or report modifier keys differently. If the gesture is unavailable, the safety timeout will still return control automatically.

## Limitations

CleanLock blocks regular keyboard and pointer events using macOS event taps. Some system-level gestures can still be handled by macOS outside the normal event stream.

CleanLock does not block the power button.

CleanLock is intended as a convenience utility, not a security lock.

## Requirements

- macOS 13.0 or later
- Xcode 15 or later recommended

## Build From Source

Clone the repository and open the Xcode project:

```bash
git clone <repository-url>
cd CleanLock
open CleanLock.xcodeproj
```

Then select the `CleanLock` scheme and run the app from Xcode.

The first launch will show onboarding and guide you through the required macOS permissions.

## Tech Stack

- Swift
- SwiftUI
- AppKit
- CGEventTap
- ServiceManagement
- UserDefaults

## Project Status

CleanLock is a focused macOS utility. It is usable, intentionally small, and built around one job: making it less annoying to clean a MacBook without triggering random input.

Issues and pull requests are welcome.

## License

CleanLock is released under the MIT License. See [LICENSE](LICENSE).

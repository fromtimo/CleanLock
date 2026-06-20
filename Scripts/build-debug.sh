#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/Debug"
APP_DIR="$BUILD_DIR/CleanLock.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE_DIR="/private/tmp/cleanlock-module-cache"

SWIFT_FILES=(
  "$ROOT_DIR/CleanLock/App/AppDelegate.swift"
  "$ROOT_DIR/CleanLock/App/CleanLockApp.swift"
  "$ROOT_DIR/CleanLock/Controllers/MenuBarController.swift"
  "$ROOT_DIR/CleanLock/Controllers/SettingsWindowController.swift"
  "$ROOT_DIR/CleanLock/Managers/CleaningModeManager.swift"
  "$ROOT_DIR/CleanLock/Managers/CleaningSessionStore.swift"
  "$ROOT_DIR/CleanLock/Managers/CursorController.swift"
  "$ROOT_DIR/CleanLock/Managers/InputBlocker.swift"
  "$ROOT_DIR/CleanLock/Managers/OverlayManager.swift"
  "$ROOT_DIR/CleanLock/Managers/PermissionManager.swift"
  "$ROOT_DIR/CleanLock/Managers/IdleSleepAssertion.swift"
  "$ROOT_DIR/CleanLock/Managers/SessionLockObserver.swift"
  "$ROOT_DIR/CleanLock/Managers/PointerDeviceSeizer.swift"
  "$ROOT_DIR/CleanLock/Managers/PreferencesStore.swift"
  "$ROOT_DIR/CleanLock/Models/AutoUnlockDuration.swift"
  "$ROOT_DIR/CleanLock/Models/CleaningModeState.swift"
  "$ROOT_DIR/CleanLock/Models/DisplayScope.swift"
  "$ROOT_DIR/CleanLock/Models/Localization.swift"
  "$ROOT_DIR/CleanLock/Models/OnboardingStep.swift"
  "$ROOT_DIR/CleanLock/Views/AnimatedLockIcon.swift"
  "$ROOT_DIR/CleanLock/Views/CleaningOverlayView.swift"
  "$ROOT_DIR/CleanLock/Views/OnboardingView.swift"
  "$ROOT_DIR/CleanLock/Views/SettingsView.swift"
)

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"

swiftc \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -g \
  -Onone \
  -D DEBUG \
  -o "$MACOS_DIR/CleanLock" \
  "${SWIFT_FILES[@]}"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>CleanLock</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>dev.cleanlock.CleanLock</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>CleanLock</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.2</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSInputMonitoringUsageDescription</key>
	<string>CleanLock uses input monitoring only to detect holding the left and right Command keys during cleaning mode.</string>
	<key>NSSupportsAutomaticTermination</key>
	<false/>
	<key>NSSupportsSuddenTermination</key>
	<false/>
</dict>
</plist>
PLIST

cp "$ROOT_DIR/CleanLock/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
mkdir -p "$RESOURCES_DIR/en.lproj" "$RESOURCES_DIR/ru.lproj"
cp "$ROOT_DIR/CleanLock/Resources/en.lproj/InfoPlist.strings" "$RESOURCES_DIR/en.lproj/InfoPlist.strings"
cp "$ROOT_DIR/CleanLock/Resources/ru.lproj/InfoPlist.strings" "$RESOURCES_DIR/ru.lproj/InfoPlist.strings"

echo "$APP_DIR"

#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="FocusLock"
BUNDLE_ID="com.focuslock.FocusLock"
APP_DIR="${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"
PLUGINS_DIR="${CONTENTS}/PlugIns"

WIDGET_NAME="FocusLockWidget"
WIDGET_BUNDLE="${WIDGET_NAME}.appex"
WIDGET_DIR="${PLUGINS_DIR}/${WIDGET_BUNDLE}"
WIDGET_CONTENTS="${WIDGET_DIR}/Contents"
WIDGET_MACOS="${WIDGET_CONTENTS}/MacOS"

echo "[build] Cleaning previous build..."
rm -rf "${APP_DIR}"

echo "[build] Creating bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${WIDGET_MACOS}"

echo "[build] Copying Info.plist..."
cp Info.plist "${CONTENTS}/Info.plist"

echo "[build] Copying app icon..."
cp Resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"

echo "[build] Compiling Swift sources..."
swiftc \
    -target arm64-apple-macosx14.0 \
    -O \
    -parse-as-library \
    -framework AppKit \
    -framework SwiftUI \
    -framework UserNotifications \
    -framework ApplicationServices \
    -framework ServiceManagement \
    -framework WidgetKit \
    -framework Combine \
    -o "${MACOS_DIR}/${APP_NAME}" \
    Sources/FocusLockApp.swift \
    Sources/MainTabView.swift \
    Sources/ContentView.swift \
    Sources/FocusManager.swift \
    Sources/AppListView.swift \
    Sources/TimerPickerView.swift \
    Sources/GlassPanel.swift \
    Sources/WebsiteBlocker.swift \
    Sources/WebsiteListView.swift \
    Sources/SessionStore.swift \
    Sources/HistoryView.swift \
    Sources/SettingsStore.swift \
    Sources/SettingsView.swift \
    Sources/ScheduleStore.swift \
    Sources/ScheduleView.swift \
    Sources/WidgetSync.swift

echo "[build] Compiling widget extension..."
cp Widget/Info.plist "${WIDGET_CONTENTS}/Info.plist"
swiftc \
    -target arm64-apple-macosx14.0 \
    -O \
    -parse-as-library \
    -framework SwiftUI \
    -framework WidgetKit \
    -o "${WIDGET_MACOS}/${WIDGET_NAME}" \
    Widget/FocusLockWidget.swift

echo "[build] Stripping extended attributes..."
xattr -cr "${APP_DIR}"

# Strip the FinderInfo / fileprovider attrs that macOS re-adds to bundle dirs.
strip_detritus() {
    xattr -d com.apple.FinderInfo "$1" 2>/dev/null || true
    xattr -d "com.apple.fileprovider.fpfs#P" "$1" 2>/dev/null || true
}

echo "[build] Code-signing widget extension..."
strip_detritus "${WIDGET_DIR}"
codesign --force --options runtime --entitlements Widget/FocusLockWidget.entitlements --sign - "${WIDGET_DIR}"

echo "[build] Code-signing main app (ad-hoc + hardened runtime + entitlements) ..."
strip_detritus "${APP_DIR}"
SIGN_ARGS=(--force --deep --options runtime --entitlements FocusLock.entitlements --sign -)
codesign "${SIGN_ARGS[@]}" "${APP_DIR}" 2>&1 || {
    strip_detritus "${APP_DIR}"
    strip_detritus "${WIDGET_DIR}"
    codesign "${SIGN_ARGS[@]}" "${APP_DIR}"
}

echo "[build] Verifying signature..."
codesign --verify --verbose "${APP_DIR}"

echo "[build] Build complete: ${APP_DIR}"

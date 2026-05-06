#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="FocusLock"
BUNDLE_ID="com.focuslock.FocusLock"
APP_DIR="${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

echo "[build] Cleaning previous build..."
rm -rf "${APP_DIR}"

echo "[build] Creating bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "[build] Copying Info.plist..."
cp Info.plist "${CONTENTS}/Info.plist"

echo "[build] Compiling Swift sources..."
swiftc \
    -target arm64-apple-macosx13.0 \
    -O \
    -parse-as-library \
    -framework AppKit \
    -framework SwiftUI \
    -framework UserNotifications \
    -framework ApplicationServices \
    -o "${MACOS_DIR}/${APP_NAME}" \
    Sources/FocusLockApp.swift \
    Sources/ContentView.swift \
    Sources/FocusManager.swift \
    Sources/AppListView.swift \
    Sources/TimerPickerView.swift \
    Sources/GlassPanel.swift \
    Sources/WebsiteBlocker.swift \
    Sources/WebsiteListView.swift

echo "[build] Stripping extended attributes..."
xattr -cr "${APP_DIR}"
xattr -d com.apple.FinderInfo "${APP_DIR}" 2>/dev/null || true
xattr -d "com.apple.fileprovider.fpfs#P" "${APP_DIR}" 2>/dev/null || true

echo "[build] Code-signing (ad-hoc + hardened runtime + entitlements) ..."
SIGN_ARGS=(--force --deep --options runtime --entitlements FocusLock.entitlements --sign -)
codesign "${SIGN_ARGS[@]}" "${APP_DIR}" 2>&1 || {
    xattr -d com.apple.FinderInfo "${APP_DIR}" 2>/dev/null || true
    xattr -d "com.apple.fileprovider.fpfs#P" "${APP_DIR}" 2>/dev/null || true
    codesign "${SIGN_ARGS[@]}" "${APP_DIR}"
}

echo "[build] Verifying signature..."
codesign --verify --verbose "${APP_DIR}"

echo "[build] Build complete: ${APP_DIR}"

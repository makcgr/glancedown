#!/usr/bin/env bash
# Builds Glancedown.app (viewer + Quick Look extension) and Glancedown Editor.app into build/.
#
# Environment:
#   VERSION        marketing version written into Info.plist (default: from Support/Glancedown-Info.plist)
#   UNIVERSAL=1    build arm64 + x86_64 (needs full Xcode; Command Line Tools build the host arch only)
#   SIGN_IDENTITY  codesign identity, e.g. "Developer ID Application: Name (TEAMID)"; default "-" (ad hoc)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
BUILD_ARGS=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

swift build "${BUILD_ARGS[@]}"
BIN="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

APP="$ROOT/build/Glancedown.app"
APPEX="$APP/Contents/PlugIns/GlancedownQuickLook.appex"
EDITOR="$ROOT/build/Glancedown Editor.app"
rm -rf "$APP" "$EDITOR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS"
mkdir -p "$EDITOR/Contents/MacOS" "$EDITOR/Contents/Resources"

cp "$BIN/Glancedown" "$APP/Contents/MacOS/"
cp Support/Glancedown-Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/"
cp -R Sources/RenderCore/Web "$APP/Contents/Resources/Web"

cp "$BIN/GlancedownQuickLook" "$APPEX/Contents/MacOS/"
cp Support/QuickLook-Info.plist "$APPEX/Contents/Info.plist"

cp "$BIN/GlancedownEditor" "$EDITOR/Contents/MacOS/"
cp Support/Editor-Info.plist "$EDITOR/Contents/Info.plist"
cp Support/EditorIcon.icns "$EDITOR/Contents/Resources/"
cp -R Sources/RenderCore/Web "$EDITOR/Contents/Resources/Web"

if [[ -n "${VERSION:-}" ]]; then
  for plist in "$APP/Contents/Info.plist" "$APPEX/Contents/Info.plist" "$EDITOR/Contents/Info.plist"; do
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-$VERSION}" "$plist"
  done
fi

SIGN_ARGS=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi
codesign "${SIGN_ARGS[@]}" --entitlements Support/QuickLook.entitlements "$APPEX"
codesign "${SIGN_ARGS[@]}" "$APP"
codesign "${SIGN_ARGS[@]}" "$EDITOR"
codesign --verify --deep --strict "$APP"
codesign --verify --deep --strict "$EDITOR"
echo "Built $APP and $EDITOR ($(lipo -archs "$APP/Contents/MacOS/Glancedown"), signed with '$SIGN_IDENTITY')"

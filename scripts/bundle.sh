#!/usr/bin/env bash
# Builds Glancedown.app (with the Quick Look extension) into build/ and signs it ad hoc.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

APP="$ROOT/build/Glancedown.app"
APPEX="$APP/Contents/PlugIns/GlancedownQuickLook.appex"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS"

cp "$BIN/Glancedown" "$APP/Contents/MacOS/"
cp Support/Glancedown-Info.plist "$APP/Contents/Info.plist"
cp -R Sources/RenderCore/Web "$APP/Contents/Resources/Web"

cp "$BIN/GlancedownQuickLook" "$APPEX/Contents/MacOS/"
cp Support/QuickLook-Info.plist "$APPEX/Contents/Info.plist"

codesign --force --sign - --entitlements Support/QuickLook.entitlements "$APPEX"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"

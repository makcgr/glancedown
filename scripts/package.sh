#!/usr/bin/env bash
# Packs build/*.app into dist/Glancedown-<version>.dmg and, when credentials are set, notarizes it.
#
# Environment:
#   VERSION                 required, e.g. 0.2.0
#   SIGN_IDENTITY           Developer ID identity used to sign the DMG (optional)
#   NOTARY_KEY_PATH         App Store Connect API key (.p8) for notarytool (optional)
#   NOTARY_KEY_ID, NOTARY_ISSUER_ID
set -euo pipefail

: "${VERSION:?set VERSION}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DMG="dist/Glancedown-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

mkdir -p dist
cp -R build/*.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Glancedown $VERSION" -srcfolder "$STAGING" -format UDZO -fs HFS+ "$DMG"

if [[ -n "${SIGN_IDENTITY:-}" && "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi

if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
  xcrun notarytool submit "$DMG" --wait \
    --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID"
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG"
else
  echo "NOTARY_KEY_PATH not set: DMG is not notarized (Gatekeeper will warn on other Macs)."
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"

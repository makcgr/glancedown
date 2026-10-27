#!/usr/bin/env bash
# Runs the test suite. With only the Command Line Tools installed, swift-testing needs explicit framework paths.
set -euo pipefail
cd "$(dirname "$0")/.."

FRAMEWORKS=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
if xcode-select -p | grep -q CommandLineTools && [ -d "$FRAMEWORKS" ]; then
  exec swift test -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xswiftc -F"$FRAMEWORKS" -Xlinker -F"$FRAMEWORKS" -Xlinker -rpath -Xlinker "$FRAMEWORKS" "$@"
fi
exec swift test "$@"

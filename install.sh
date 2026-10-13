#!/bin/sh
# Builds KeyCount from source and installs it to /Applications (override with INSTALL_DIR).
set -eu
cd "$(dirname "$0")"

BUNDLE_ID=dev.keycount.KeyCount
INSTALL_DIR=${INSTALL_DIR:-/Applications}
APP="$INSTALL_DIR/KeyCount.app"

if ! xcrun --find swift >/dev/null 2>&1; then
  echo "KeyCount needs Apple's Command Line Tools. Starting the installer now;"
  echo "run ./install.sh again when it finishes."
  xcode-select --install || true
  exit 1
fi

echo "Building KeyCount..."
swift build -c release --product KeyCount

STAGE=build/KeyCount.app
rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/KeyCount" "$STAGE/Contents/MacOS/KeyCount"
cp Resources/Info.plist "$STAGE/Contents/Info.plist"
codesign --force --sign - --identifier "$BUNDLE_ID" "$STAGE"

pkill -x KeyCount 2>/dev/null && sleep 1 || true
mkdir -p "$INSTALL_DIR"
rm -rf "$APP"
cp -R "$STAGE" "$APP"

# Each build has a new ad-hoc signature, so an old Input Monitoring grant no longer matches it.
# Clearing it makes macOS ask again instead of showing a switch that is on but does nothing.
tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true

open "$APP"
echo "Installed $APP. Click the keyboard icon in the menu bar to finish setup."

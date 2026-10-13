#!/bin/sh
# Removes KeyCount, its login item, its permission grant, and its saved counts.
set -eu
BUNDLE_ID=dev.keycount.KeyCount
APP="${INSTALL_DIR:-/Applications}/KeyCount.app"

pkill -x KeyCount 2>/dev/null || true
[ -x "$APP/Contents/MacOS/KeyCount" ] && "$APP/Contents/MacOS/KeyCount" --unregister || true
tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true
rm -rf "$APP" "$HOME/Library/Application Support/KeyCount"
defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "KeyCount removed."

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Snapbar

APP=Snapbar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Snapbar "$APP/Contents/MacOS/Snapbar"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# A stable identity keeps Screen Recording and Accessibility grants across rebuilds.
IDENTITY="-"
if security find-identity -v -p codesigning | grep -q "Snapbar Dev"; then
  IDENTITY="Snapbar Dev"
fi
codesign --force --sign "$IDENTITY" --identifier dev.local.snapbar "$APP"
echo "Built $APP, signed with: $IDENTITY"

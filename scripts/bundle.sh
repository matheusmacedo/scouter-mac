#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product Scouter

APP=Scouter.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Scouter "$APP/Contents/MacOS/Scouter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Regenerate these with: swift scripts/make-icon.swift
cp Resources/AppIcon.icns Resources/MenuBarIcon.png Resources/MenuBarIcon@2x.png "$APP/Contents/Resources/"

# A stable identity keeps Screen Recording and Accessibility grants across rebuilds.
# No -v: a self-signed certificate counts as untrusted until set to Always Trust, and -v would hide it.
IDENTITY="-"
if security find-identity -p codesigning | grep -q "Scouter Dev"; then
  IDENTITY="Scouter Dev"
fi
codesign --force --sign "$IDENTITY" --identifier dev.local.scouter "$APP"
echo "Built $APP, signed with: $IDENTITY"

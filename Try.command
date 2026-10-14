#!/bin/bash
# Build and launch a *temporary* trial app. No privileged access or installs.
set -euo pipefail
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Apple Command Line Tools are not installed. No changes made."
  echo "Please do not install anything yet; report this message."
  read -r -p "Press Return to close. " _
  exit 1
fi

BUILD_DIR="$PWD/Trial"
APP="$BUILD_DIR/Brightness Menu.app"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"

if ! xcrun clang -fobjc-arc -mmacosx-version-min=10.13 \
    -framework Cocoa -framework CoreGraphics \
    -o "$APP/Contents/MacOS/BrightnessMenu" main.m; then
  echo "Build failed; no app was installed."
  read -r -p "Press Return to close. " _
  exit 1
fi

chmod +x "$APP/Contents/MacOS/BrightnessMenu"
echo "Built trial app: $APP"
echo "Launching — look for a sun icon in the menu bar."
open "$APP"
echo "If it works, you may drag the .app from Trial to Applications."
echo "If it does not work, quit it, then delete the Trial folder."
read -r -p "Press Return to close this Terminal window. " _

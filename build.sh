#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP_NAME="$(cat APP_NAME)"
BUILD_DIR="${BUILD_DIR:-build}"
APP="$BUILD_DIR/$APP_NAME.app"
mkdir -p "$BUILD_DIR/module-cache" "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -module-cache-path "$BUILD_DIR/module-cache" Sources/*.swift -o "$APP/Contents/MacOS/$APP_NAME" -framework AppKit -framework SwiftUI -framework ScreenCaptureKit -framework CoreImage -framework MetalKit -framework IOKit -framework Carbon -framework ServiceManagement
cp Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$APP/Contents/Info.plist"
cp Resources/Logo.png "$APP/Contents/Resources/"
cp Resources/Fold.metal "$APP/Contents/Resources/"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
codesign --force --sign "${SIGNING_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"

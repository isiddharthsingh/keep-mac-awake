#!/bin/bash
# Builds the menu bar app and wraps it in a .app bundle at build/<APP_NAME>.app
set -euo pipefail

# Rename the app here; the menu and panel pick the name up from the bundle.
APP_NAME="MacAwake"
BUNDLE_ID="com.siddharth.macawake"

# Release builds set VERSION from the git tag. Sparkle compares BUILD_NUMBER to decide what is newer.
VERSION="${VERSION:-0.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
FEED_URL="${FEED_URL:-https://github.com/isiddharthsingh/keep-mac-awake/releases/latest/download/appcast.xml}"
# Public half of the Sparkle signing key; the private half lives in the keychain and a GitHub secret.
SPARKLE_PUBLIC_KEY="8Y/ED2UvSOHyYp/SxQfiv3Lr3ceHNV2ebO/68ajhI6c="

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --product Awake
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="$ROOT/build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
cp "$BIN_DIR/Awake" "$APP/Contents/MacOS/$APP_NAME"
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>SUFeedURL</key><string>$FEED_URL</string>
    <key>SUPublicEDKey</key><string>$SPARKLE_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP ($VERSION, build $BUILD_NUMBER)"

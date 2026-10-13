#!/bin/bash
# Builds the app, packages it as build/MacAwake.dmg, and writes build/appcast.xml for Sparkle updates.
# Usage: VERSION=1.2.0 ./scripts/make-release.sh
# Signs with SPARKLE_PRIVATE_KEY when set (CI), otherwise with the key in the login keychain.
set -euo pipefail

: "${VERSION:?Set VERSION, e.g. VERSION=1.2.0}"
export VERSION
REPO_URL="https://github.com/isiddharthsingh/keep-mac-awake"
DOWNLOAD_URL="${DOWNLOAD_URL:-$REPO_URL/releases/download/v$VERSION/MacAwake.dmg}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/build-app.sh
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" build/MacAwake.app/Contents/Info.plist)"

# Disk image: the app on the left, an Applications shortcut on the right, over assets/dmg-background.png.
# dmgbuild runs from a private virtualenv so the system Python stays untouched.
DMGBUILD_VENV=.build/dmgbuild-venv
if [ ! -x "$DMGBUILD_VENV/bin/dmgbuild" ]; then
    python3 -m venv "$DMGBUILD_VENV"
    "$DMGBUILD_VENV/bin/pip" install --quiet "dmgbuild==1.6.7"
fi
rm -f build/MacAwake.dmg
"$DMGBUILD_VENV/bin/dmgbuild" -s scripts/dmg_settings.py \
    -D app=build/MacAwake.app -D background=assets/dmg-background.png \
    MacAwake build/MacAwake.dmg

SIGN_UPDATE=.build/artifacts/sparkle/Sparkle/bin/sign_update
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    SIGNATURE="$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - build/MacAwake.dmg)"
else
    SIGNATURE="$("$SIGN_UPDATE" --account MacAwake build/MacAwake.dmg)"
fi

cat > build/appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MacAwake</title>
    <item>
      <title>MacAwake $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>$REPO_URL/releases/tag/v$VERSION</sparkle:fullReleaseNotesLink>
      <enclosure url="$DOWNLOAD_URL" $SIGNATURE type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

echo "Built build/MacAwake.dmg and build/appcast.xml ($VERSION, build $BUILD_NUMBER)"

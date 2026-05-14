#!/usr/bin/env bash
set -euo pipefail

REPO="nickleefly/voice-input"
APP="VoiceInput.app"
DEST="/Applications/$APP"
BUNDLE_ID="com.voiceinput.app"

echo "→ Fetching latest release info…"
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep browser_download_url \
  | grep '\.zip' \
  | head -1 \
  | cut -d '"' -f 4)

if [ -z "${URL:-}" ]; then
  echo "ERROR: could not find a .zip asset in the latest release of $REPO" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "→ Downloading $URL"
curl -fsSL "$URL" -o "$TMP/vi.zip"

echo "→ Unpacking…"
unzip -q -o "$TMP/vi.zip" -d "$TMP"

if [ ! -d "$TMP/$APP" ]; then
  echo "ERROR: expected $APP inside the release zip" >&2
  exit 1
fi

echo "→ Quitting any running instance…"
pkill -f "$APP/Contents/MacOS/VoiceInput" 2>/dev/null || true

echo "→ Installing to $DEST…"
[ -d "$DEST" ] && rm -rf "$DEST"
mv "$TMP/$APP" "$DEST"

echo "→ Removing quarantine attribute…"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "→ Re-signing locally (ad-hoc, stable on this machine)…"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$DEST"

echo "→ Clearing any stale permission grants…"
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null || true
tccutil reset SpeechRecognition "$BUNDLE_ID" 2>/dev/null || true
tccutil reset ListenEvent "$BUNDLE_ID" 2>/dev/null || true

echo "→ Launching VoiceInput…"
open "$DEST"

cat <<'EOF'

✅ Installed.

Next steps:
  1. When System Settings opens, toggle VoiceInput ON under
     Privacy & Security → Accessibility.
  2. Quit VoiceInput from the menu bar (click the icon → Quit).
  3. Relaunch it from /Applications (or run: open /Applications/VoiceInput.app).
  4. Hold the Fn key to record, release to inject.

If the Fn key still doesn't trigger, check ~/.voiceinput-debug.log
and report the contents.
EOF

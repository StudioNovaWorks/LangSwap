#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="LangSwap"
APP_BUNDLE="$PROJECT_ROOT/dist/${APP_NAME}.app"

DO_BUILD=0
UNIVERSAL=0
NO_FINDER_LAYOUT=0
BUILD_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --build)
            DO_BUILD=1
            ;;
        --universal)
            UNIVERSAL=1
            BUILD_ARGS+=(--universal)
            ;;
        --no-finder-layout)
            NO_FINDER_LAYOUT=1
            ;;
        *)
            echo "❌ Unknown option: $arg (supported: --build, --universal, --no-finder-layout)" >&2
            exit 2
            ;;
    esac
done

if [ "$UNIVERSAL" -eq 1 ] && [ "$DO_BUILD" -eq 0 ] && [ -d "$APP_BUNDLE" ]; then
    EXISTING_ARCH="$(lipo -info "$APP_BUNDLE/Contents/MacOS/${APP_NAME}" 2>/dev/null || true)"
    if [[ "$EXISTING_ARCH" != *"x86_64"* ]]; then
        echo "ℹ️  Existing app is not Universal ($EXISTING_ARCH); rebuilding with --universal..."
        DO_BUILD=1
    fi
fi

if [ "$DO_BUILD" -eq 1 ] || [ ! -d "$APP_BUNDLE" ]; then
    if [ "${#BUILD_ARGS[@]}" -gt 0 ]; then
        "$PROJECT_ROOT/build_app.sh" "${BUILD_ARGS[@]}"
    else
        "$PROJECT_ROOT/build_app.sh"
    fi
fi

if [ ! -f "$APP_BUNDLE/Contents/Info.plist" ]; then
    echo "❌ Missing Info.plist in $APP_BUNDLE" >&2
    exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist")"
if [ -z "$APP_VERSION" ]; then
    echo "❌ Could not read CFBundleShortVersionString from $APP_BUNDLE/Contents/Info.plist" >&2
    exit 1
fi

BG_SCRIPT="$PROJECT_ROOT/scripts/generate_dmg_background.swift"
BG_TIFF="$PROJECT_ROOT/Resources/dmg_background.tiff"
if [ ! -f "$BG_TIFF" ] || [ "$BG_SCRIPT" -nt "$BG_TIFF" ] || [ "$PROJECT_ROOT/Info.plist" -nt "$BG_TIFF" ]; then
    echo "🎨 Generating Retina DMG background image..."
    swift "$BG_SCRIPT" --version "$APP_VERSION" --out "$BG_TIFF"
fi

DMG_PATH="$PROJECT_ROOT/dist/${APP_NAME}-v${APP_VERSION}.dmg"
WORK_DIR="$(mktemp -d)"
STAGE_DIR="$WORK_DIR/stage"
RW_DMG="$WORK_DIR/${APP_NAME}-rw.dmg"
DEVICE=""

cleanup() {
    if [ -n "${DEVICE:-}" ]; then
        hdiutil detach "$DEVICE" -quiet 2>/dev/null || hdiutil detach "$DEVICE" -force -quiet 2>/dev/null || true
        DEVICE=""
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [ -d "/Volumes/${APP_NAME}" ]; then
    if diskutil info "/Volumes/${APP_NAME}" 2>/dev/null | grep -q "Disk Image"; then
        echo "ℹ️  Detaching existing disk image at /Volumes/${APP_NAME}..."
        hdiutil detach "/Volumes/${APP_NAME}" || hdiutil detach "/Volumes/${APP_NAME}" -force
    else
        echo "❌ /Volumes/${APP_NAME} already exists and is not a disk image." >&2
        exit 1
    fi
fi

mkdir -p "$STAGE_DIR/.background"
echo "📦 Staging DMG contents for ${APP_NAME} v${APP_VERSION}..."
ditto "$APP_BUNDLE" "$STAGE_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGE_DIR/Applications"
cp "$BG_TIFF" "$STAGE_DIR/.background/dmg_background.tiff"

STAGE_KB="$(du -sk "$STAGE_DIR" | awk '{print $1}')"
DMG_MB="$((STAGE_KB / 1024 + 24))"

echo "🛠️  Creating writable HFS+ staging DMG (${DMG_MB} MB)..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$STAGE_DIR" \
    -fs HFS+ \
    -format UDRW \
    -size "${DMG_MB}m" \
    -ov \
    "$RW_DMG"

echo "🔌 Attaching staging DMG to configure Finder window layout..."
ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
DEVICE="$(echo "$ATTACH_OUTPUT" | awk '/^\/dev\/disk/{print $1; exit}')"
MOUNT_DIR="$(echo "$ATTACH_OUTPUT" | sed -n 's/.*\(\/Volumes\/.*\)$/\1/p' | head -n 1)"

if [ -z "$DEVICE" ] || [ ! -d "$MOUNT_DIR" ]; then
    echo "❌ Failed to attach staging DMG ($DEVICE / $MOUNT_DIR)" >&2
    exit 1
fi

chflags hidden "$MOUNT_DIR/.background"

if [ "$NO_FINDER_LAYOUT" -eq 0 ]; then
    echo "🖼️  Applying Finder window bounds, icon positions, and background..."
    if ! /usr/bin/osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {160, 120, 760, 548}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:dmg_background.tiff"
        set position of item "${APP_NAME}.app" of container window to {160, 114}
        set position of item "Applications" of container window to {440, 114}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF
    then
        echo "❌ Finder layout automation failed (GUI session/Finder access is unavailable, e.g., headless CI or SSH)." >&2
        echo "   Re-run with --no-finder-layout to package the DMG without Finder window layout." >&2
        exit 1
    fi
else
    echo "⏭️  Skipping Finder window layout (--no-finder-layout enabled)."
fi

# Apply custom volume icon after Finder styling; Finder's update clears .VolumeIcon.icns and bit C if set beforehand.
VOL_ICON="$PROJECT_ROOT/Resources/AppIcon.icns"
if [ ! -f "$VOL_ICON" ] && [ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
    VOL_ICON="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -f "$VOL_ICON" ]; then
    cp "$VOL_ICON" "$MOUNT_DIR/.VolumeIcon.icns"
    if command -v SetFile >/dev/null 2>&1; then
        SetFile -a C "$MOUNT_DIR"
    fi
    chflags hidden "$MOUNT_DIR/.VolumeIcon.icns"
fi

sync

if [ "$NO_FINDER_LAYOUT" -eq 0 ] && [ ! -s "$MOUNT_DIR/.DS_Store" ]; then
    echo "❌ Finder failed to write a non-empty .DS_Store inside $MOUNT_DIR" >&2
    exit 1
fi

DETACHED=0
for attempt in 1 2 3 4 5; do
    if hdiutil detach "$DEVICE" >/dev/null 2>&1; then
        DETACHED=1
        break
    fi
    sleep 1
done
if [ "$DETACHED" -ne 1 ]; then
    hdiutil detach "$DEVICE" -force
fi
DEVICE=""

rm -f "$DMG_PATH"
echo "💿 Converting to compressed disk image: $DMG_PATH..."
hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "$DMG_PATH"

SIGN_IDENTITY="${LANGSWAP_SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application:/ {print $2; exit}' || true)"
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "✍️  Signing disk image with identity: ${SIGN_IDENTITY}..."
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

echo "🔍 Verifying disk image integrity..."
hdiutil verify "$DMG_PATH"

DMG_SIZE="$(du -sh "$DMG_PATH" | awk '{print $1}')"
DMG_SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
echo "✅ DMG ready: $DMG_PATH ($DMG_SIZE)"
echo "🔑 SHA-256: $DMG_SHA256"
